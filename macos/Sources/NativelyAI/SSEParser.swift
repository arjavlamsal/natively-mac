import Foundation

public struct SSEEvent: Sendable, Equatable {
    public let event: String?
    public let data: String
    
    public init(event: String? = nil, data: String) {
        self.event = event
        self.data = data
    }
}

/// State machine parser for Server-Sent Events (SSE) data streams.
public struct SSEParser: Sendable {
    private var currentEvent: String?
    private var currentData: [String] = []
    
    public init() {}
    
    /// Feeds a single incoming line from an SSE stream.
    /// Returns an `SSEEvent` when an event delimiter (empty line) or a new self-contained data frame is encountered.
    public mutating func feed(line: String) -> SSEEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            if !currentData.isEmpty {
                let joined = currentData.joined(separator: "\n")
                let event = SSEEvent(event: currentEvent, data: joined)
                currentEvent = nil
                currentData.removeAll()
                return event
            }
            return nil
        }
        
        if line.hasPrefix("event:") {
            var previousEvent: SSEEvent? = nil
            if !currentData.isEmpty {
                previousEvent = SSEEvent(event: currentEvent, data: currentData.joined(separator: "\n"))
                currentData.removeAll()
            }
            currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            return previousEvent
        } else if line.hasPrefix("data:") {
            var payload = String(line.dropFirst(5))
            if payload.hasPrefix(" ") {
                payload.removeFirst()
            }
            
            let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If there was prior data and another data: line arrives without an empty line, flush prior data
            if !currentData.isEmpty {
                let prior = currentData.joined(separator: "\n")
                currentData = [payload]
                let event = SSEEvent(event: currentEvent, data: prior)
                return event
            }
            
            // Fast-path: If incoming line is a self-contained complete JSON or [DONE] with no pending event header, emit immediately
            if currentEvent == nil && ((trimmedPayload.hasPrefix("{") && trimmedPayload.hasSuffix("}")) || trimmedPayload == "[DONE]") {
                return SSEEvent(event: nil, data: payload)
            }
            
            currentData.append(payload)
        }
        
        return nil
    }
    
    /// Flushes any trailing event at the end of the stream.
    public mutating func finish() -> SSEEvent? {
        if !currentData.isEmpty {
            let joined = currentData.joined(separator: "\n")
            let event = SSEEvent(event: currentEvent, data: joined)
            currentEvent = nil
            currentData.removeAll()
            return event
        }
        return nil
    }
}
