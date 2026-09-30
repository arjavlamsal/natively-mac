import Foundation
import NativelyCore

/// Unified streaming client for OpenAI-compatible endpoints (OpenAI, Groq, DeepSeek).
public final class OpenAICompatibleStreamingClient: StreamingAIProvider, Sendable {
    public let providerType: AIProviderType
    public let baseURL: URL
    private let session: URLSession
    
    public init(
        providerType: AIProviderType,
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.providerType = providerType
        self.baseURL = baseURL
        self.session = session
    }
    
    public static func openAI(session: URLSession = .shared) -> OpenAICompatibleStreamingClient {
        OpenAICompatibleStreamingClient(
            providerType: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            session: session
        )
    }
    
    public static func groq(session: URLSession = .shared) -> OpenAICompatibleStreamingClient {
        OpenAICompatibleStreamingClient(
            providerType: .groq,
            baseURL: URL(string: "https://api.groq.com/openai/v1")!,
            session: session
        )
    }
    
    public static func deepseek(session: URLSession = .shared) -> OpenAICompatibleStreamingClient {
        OpenAICompatibleStreamingClient(
            providerType: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            session: session
        )
    }
    
    public func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
                    continuation.finish(throwing: AIClientError.missingAPIKey(providerType.displayName))
                    return
                }
                
                let endpoint = baseURL.appendingPathComponent("chat/completions")
                var urlRequest = URLRequest(url: endpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var messagesPayload: [[String: Any]] = []
                
                if let system = request.systemPrompt, !system.isEmpty {
                    messagesPayload.append(["role": "system", "content": system])
                }
                
                for msg in request.messages {
                    if let images = msg.base64Images, !images.isEmpty {
                        var parts: [[String: Any]] = [
                            ["type": "text", "text": msg.content]
                        ]
                        for img in images {
                            let urlString = img.hasPrefix("data:") ? img : "data:image/png;base64,\(img)"
                            parts.append([
                                "type": "image_url",
                                "image_url": ["url": urlString]
                            ])
                        }
                        messagesPayload.append(["role": msg.role.rawValue, "content": parts])
                    } else {
                        messagesPayload.append(["role": msg.role.rawValue, "content": msg.content])
                    }
                }
                
                var payload: [String: Any] = [
                    "model": request.model,
                    "messages": messagesPayload,
                    "stream": true
                ]
                
                let isReasoningModel = request.model.hasPrefix("o1") || request.model.hasPrefix("o3")
                if !isReasoningModel, let temp = request.temperature {
                    payload["temperature"] = temp
                }
                
                if let maxTokens = request.maxTokens {
                    if isReasoningModel {
                        payload["max_completion_tokens"] = maxTokens
                    } else {
                        payload["max_tokens"] = maxTokens
                    }
                }
                
                do {
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    let (asyncBytes, response) = try await session.bytes(for: urlRequest)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                        }
                        var userFacingMsg = errorBody
                        if let bodyData = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                           let errObj = json["error"] as? [String: Any],
                           let msg = errObj["message"] as? String {
                            userFacingMsg = msg
                        }
                        continuation.finish(throwing: AIClientError.httpError(statusCode: httpResponse.statusCode, body: userFacingMsg))
                        return
                    }
                    
                    var parser = SSEParser()
                    var hasEmittedAnyChunk = false
                    
                    for try await line in asyncBytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        
                        // Fast path: if the line directly starts with data:, parse it immediately!
                        if trimmed.hasPrefix("data:") {
                            let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            let (emitted, isTerminal) = handleSinglePayload(jsonString, continuation: continuation)
                            if emitted { hasEmittedAnyChunk = true }
                            if isTerminal { break }
                            if emitted { continue }
                        }
                        
                        if let event = parser.feed(line: line) {
                            let (emitted, isTerminal) = handleEvent(event, continuation: continuation)
                            if emitted { hasEmittedAnyChunk = true }
                            if isTerminal { break }
                        }
                    }
                    if let trailing = parser.finish() {
                        let (emitted, _) = handleEvent(trailing, continuation: continuation)
                        if emitted { hasEmittedAnyChunk = true }
                    }
                    
                    if !hasEmittedAnyChunk {
                        continuation.finish(throwing: AIClientError.emptyResponse)
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func handleEvent(_ event: SSEEvent, continuation: AsyncThrowingStream<String, Error>.Continuation) -> (emitted: Bool, isTerminal: Bool) {
        let (emitted, isTerminal) = handleSinglePayload(event.data, continuation: continuation)
        if emitted || isTerminal { return (emitted, isTerminal) }
        
        let lines = event.data.components(separatedBy: "\n")
        var anyEmitted = false
        var terminal = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let payload = trimmed.hasPrefix("data:") ? String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces) : trimmed
            let (e, t) = handleSinglePayload(payload, continuation: continuation)
            if e { anyEmitted = true }
            if t { terminal = true; break }
        }
        return (anyEmitted, terminal)
    }
    
    private func handleSinglePayload(_ dataStr: String, continuation: AsyncThrowingStream<String, Error>.Continuation) -> (emitted: Bool, isTerminal: Bool) {
        let trimmed = dataStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "[DONE]" {
            return (false, true)
        }
        
        guard let eventData = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
            return (false, false)
        }
        
        if let errObj = json["error"] as? [String: Any],
           let msg = errObj["message"] as? String {
            continuation.finish(throwing: AIClientError.httpError(statusCode: 400, body: msg))
            return (false, true)
        }
        
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any] else {
            return (false, false)
        }
        
        if let content = delta["content"] as? String, !content.isEmpty {
            continuation.yield(content)
            return (true, false)
        } else if let reasoning = (delta["reasoning_content"] as? String) ?? (delta["reasoning"] as? String), !reasoning.isEmpty {
            continuation.yield(reasoning)
            return (true, false)
        }
        return (false, false)
    }
}
