import Foundation
import NativelyCore

public enum AIClientError: Error, LocalizedError {
    case missingAPIKey(String)
    case invalidURL(String)
    case httpError(statusCode: Int, body: String)
    case decodingError(String)
    case emptyResponse
    case timeout(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): return "Missing API key for \(provider)."
        case .invalidURL(let url): return "Invalid API URL: \(url)"
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        case .decodingError(let msg): return "Failed to decode response: \(msg)"
        case .emptyResponse: return "Received empty response from AI provider."
        case .timeout(let msg): return "AI streaming timed out: \(msg)"
        }
    }
}

/// Native streaming client for Anthropic Claude (Claude 3.5 Sonnet / Haiku / Opus).
public final class AnthropicStreamingClient: StreamingAIProvider, Sendable {
    public let providerType: AIProviderType = .anthropic
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let key = apiKey, !key.isEmpty else {
                    continuation.finish(throwing: AIClientError.missingAPIKey("Anthropic"))
                    return
                }
                
                guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                    continuation.finish(throwing: AIClientError.invalidURL("https://api.anthropic.com/v1/messages"))
                    return
                }
                
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
                urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
                
                // Construct Anthropic Messages payload
                var anthropicMessages: [[String: Any]] = []
                for msg in request.messages {
                    let role = (msg.role == .assistant) ? "assistant" : "user"
                    
                    if let images = msg.base64Images, !images.isEmpty {
                        var contentBlocks: [[String: Any]] = []
                        for img in images {
                            // Extract raw base64 from data:image/png;base64,... if present
                            let cleanBase64 = img.components(separatedBy: "base64,").last ?? img
                            contentBlocks.append([
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/png",
                                    "data": cleanBase64
                                ]
                            ])
                        }
                        contentBlocks.append([
                            "type": "text",
                            "text": msg.content
                        ])
                        anthropicMessages.append(["role": role, "content": contentBlocks])
                    } else {
                        anthropicMessages.append(["role": role, "content": msg.content])
                    }
                }
                
                var payload: [String: Any] = [
                    "model": request.model,
                    "messages": anthropicMessages,
                    "max_tokens": request.maxTokens ?? 2048,
                    "stream": true
                ]
                
                if let sys = request.systemPrompt, !sys.isEmpty {
                    payload["system"] = sys
                }
                if let temp = request.temperature {
                    payload["temperature"] = temp
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
        guard let eventData = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any] else {
            return false
        }
        
        let eventType = json["type"] as? String ?? event.event
        if eventType == "content_block_delta" {
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                continuation.yield(text)
            }
        } else if eventType == "message_stop" {
            return true
        }
        return false
    }
}
