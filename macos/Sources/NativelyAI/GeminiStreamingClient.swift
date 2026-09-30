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
                guard let rawKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !rawKey.isEmpty else {
                    continuation.finish(throwing: AIClientError.missingAPIKey("Gemini"))
                    return
                }
                
                // Normalize model name (strip "models/" prefix if already present to prevent duplicate paths)
                let rawModel = request.model.hasPrefix("models/") ? String(request.model.dropFirst(7)) : request.model
                let cleanModel = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
                let targetModel = cleanModel.isEmpty ? "gemini-3.8-flash" : cleanModel
                
                let encodedModel = targetModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? targetModel
                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):streamGenerateContent?alt=sse&key=\(rawKey)"
                
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: AIClientError.invalidURL(urlString))
                    return
                }
                
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue(rawKey, forHTTPHeaderField: "x-goog-api-key")
                
                var contents: [[String: Any]] = []
                for msg in request.messages {
                    let role = (msg.role == .assistant) ? "model" : "user"
                    var parts: [[String: Any]] = []
                    
                    if let images = msg.base64Images, !images.isEmpty {
                        for img in images {
                            let cleanBase64 = img.components(separatedBy: "base64,").last ?? img
                            parts.append([
                                "inlineData": [
                                    "mimeType": "image/png",
                                    "data": cleanBase64
                                ]
                            ])
                        }
                    }
                    if !msg.content.isEmpty {
                        parts.append(["text": msg.content])
                    }
                    if !parts.isEmpty {
                        contents.append(["role": role, "parts": parts])
                    }
                }
                
                if contents.isEmpty {
                    contents.append(["role": "user", "parts": [["text": "Hello"]]])
                }
                
                var payload: [String: Any] = [
                    "contents": contents
                ]
                
                if let system = request.systemPrompt, !system.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                        if trimmed.isEmpty || trimmed == "data: [DONE]" { continue }
                        
                        // Fast path: if the line directly starts with data:, parse it immediately without buffering!
                        if trimmed.hasPrefix("data:") {
                            let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if handleSinglePayload(jsonString, continuation: continuation) {
                                hasEmittedAnyChunk = true
                                continue
                            }
                        }
                        
                        // Fallback through SSEParser
                        if let event = parser.feed(line: line) {
                            if handleEvent(event, continuation: continuation) {
                                hasEmittedAnyChunk = true
                            }
                        }
                    }
                    if let trailing = parser.finish() {
                        if handleEvent(trailing, continuation: continuation) {
                            hasEmittedAnyChunk = true
                        }
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
    
    @discardableResult
    private func handleEvent(_ event: SSEEvent, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        if handleSinglePayload(event.data, continuation: continuation) {
            return true
        }
        
        // If event.data contains multiple lines (e.g. joined by SSEParser), handle each line individually
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
    
    @discardableResult
    private func handleSinglePayload(_ payload: String, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        guard let eventData = payload.data(using: .utf8),
              let rawJson = try? JSONSerialization.jsonObject(with: eventData) else {
            return false
        }
        
        let candidateObjects: [[String: Any]]
        if let dict = rawJson as? [String: Any] {
            if let errorObj = dict["error"] as? [String: Any] {
                let msg = errorObj["message"] as? String ?? "Google Gemini API error"
                let code = errorObj["code"] as? Int ?? 400
                continuation.finish(throwing: AIClientError.httpError(statusCode: code, body: msg))
                return false
            }
            candidateObjects = dict["candidates"] as? [[String: Any]] ?? []
        } else if let array = rawJson as? [[String: Any]] {
            candidateObjects = array.first?["candidates"] as? [[String: Any]] ?? []
        } else {
            return false
        }
        
        var emitted = false
        for candidate in candidateObjects {
            guard let contentObj = candidate["content"] as? [String: Any],
                  let parts = contentObj["parts"] as? [[String: Any]] else {
                continue
            }
            for part in parts {
                if let text = part["text"] as? String, !text.isEmpty {
                    continuation.yield(text)
                    emitted = true
                }
            }
        }
        return emitted
    }
}
