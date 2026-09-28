import Foundation
import NativelyCore

/// Native streaming client for Google Gemini (Gemini 1.5 Flash / Pro).
public final class GeminiStreamingClient: StreamingAIProvider, Sendable {
    public let providerType: AIProviderType = .googleGemini
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let key = apiKey, !key.isEmpty else {
                    continuation.finish(throwing: AIClientError.missingAPIKey("Gemini"))
                    return
                }
                
                let encodedModel = request.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.model
                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):streamGenerateContent?alt=sse&key=\(key)"
                
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: AIClientError.invalidURL(urlString))
                    return
                }
                
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var contents: [[String: Any]] = []
                for msg in request.messages {
                    let role = (msg.role == .assistant) ? "model" : "user"
                    var parts: [[String: Any]] = []
                    
                    if let images = msg.base64Images, !images.isEmpty {
                        for img in images {
                            let cleanBase64 = img.components(separatedBy: "base64,").last ?? img
                            parts.append([
                                "inline_data": [
                                    "mime_type": "image/png",
                                    "data": cleanBase64
                                ]
                            ])
                        }
                    }
                    parts.append(["text": msg.content])
                    contents.append(["role": role, "parts": parts])
                }
                
                var payload: [String: Any] = [
                    "contents": contents
                ]
                
                if let system = request.systemPrompt, !system.isEmpty {
                    payload["system_instruction"] = [
                        "parts": [["text": system]]
                    ]
                }
                
                var genConfig: [String: Any] = [:]
                if let temp = request.temperature {
                    genConfig["temperature"] = temp
                }
                if let maxTokens = request.maxTokens {
                    genConfig["maxOutputTokens"] = maxTokens
                }
                if !genConfig.isEmpty {
                    payload["generationConfig"] = genConfig
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
                            handleEvent(event, continuation: continuation)
                        }
                    }
                    if let trailing = parser.finish() {
                        handleEvent(trailing, continuation: continuation)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func handleEvent(_ event: SSEEvent, continuation: AsyncThrowingStream<String, Error>.Continuation) {
        guard let eventData = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let contentObj = firstCandidate["content"] as? [String: Any],
              let parts = contentObj["parts"] as? [[String: Any]] else {
            return
        }
        
        for part in parts {
            if let text = part["text"] as? String {
                continuation.yield(text)
            }
        }
    }
}
