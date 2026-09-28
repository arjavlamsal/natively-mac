import Foundation
import NativelyCore

/// Native client for local Ollama instances (Llama 3.2, Qwen 2.5, DeepSeek R1).
public final class OllamaStreamingClient: StreamingAIProvider, Sendable {
    public let providerType: AIProviderType = .ollama
    public let hostURL: URL
    private let session: URLSession
    
    public init(
        hostURL: URL = URL(string: "http://127.0.0.1:11434")!,
        session: URLSession = .shared
    ) {
        self.hostURL = hostURL
        self.session = session
    }
    
    public func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let endpoint = hostURL.appendingPathComponent("api/chat")
                var urlRequest = URLRequest(url: endpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var messagesPayload: [[String: Any]] = []
                
                if let system = request.systemPrompt, !system.isEmpty {
                    messagesPayload.append(["role": "system", "content": system])
                }
                
                for msg in request.messages {
                    var messageDict: [String: Any] = [
                        "role": msg.role.rawValue,
                        "content": msg.content
                    ]
                    if let images = msg.base64Images, !images.isEmpty {
                        var cleanImages: [String] = []
                        for img in images {
                            let clean = img.components(separatedBy: "base64,").last ?? img
                            cleanImages.append(clean)
                        }
                        messageDict["images"] = cleanImages
                    }
                    messagesPayload.append(messageDict)
                }
                
                var payload: [String: Any] = [
                    "model": request.model,
                    "messages": messagesPayload,
                    "stream": true
                ]
                
                if let temp = request.temperature {
                    payload["options"] = ["temperature": temp]
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
                    
                    for try await line in asyncBytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty,
                              let data = trimmed.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }
                        
                        if let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(content)
                        }
                        
                        if let isDone = json["done"] as? Bool, isDone {
                            break
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
