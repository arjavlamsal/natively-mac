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
                guard let key = apiKey, !key.isEmpty else {
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
                
                if let temp = request.temperature {
                    payload["temperature"] = temp
                }
                if let maxTokens = request.maxTokens {
                    payload["max_tokens"] = maxTokens
                }
                
                do {
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                    let (asyncBytes, response) = try await session.bytes(for: urlRequest)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: AIClientError.httpError(statusCode: httpResponse.statusCode, body: errorBody))
                        return
                    }
                    
                    var parser = SSEParser()
                    for try await line in asyncBytes.lines {
                        if let event = parser.feed(line: line) {
                            if handleEvent(event, continuation: continuation) {
                                break
                            }
                        }
                    }
                    if let trailing = parser.finish() {
                        _ = handleEvent(trailing, continuation: continuation)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func handleEvent(_ event: SSEEvent, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        if handleSinglePayload(event.data, continuation: continuation) {
            return true
        }
        
        let lines = event.data.components(separatedBy: "\n")
        var anyEmitted = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "[DONE]" || trimmed == "data: [DONE]" { continue }
            let payload = trimmed.hasPrefix("data:") ? String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces) : trimmed
            if handleSinglePayload(payload, continuation: continuation) {
                anyEmitted = true
            }
        }
        return anyEmitted
    }
    
    private func handleSinglePayload(_ dataStr: String, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        let trimmed = dataStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "[DONE]" {
            return true
        }
        
        guard let eventData = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any] else {
            return false
        }
        
        if let content = delta["content"] as? String {
            continuation.yield(content)
            return true
        }
        return false
    }
}
