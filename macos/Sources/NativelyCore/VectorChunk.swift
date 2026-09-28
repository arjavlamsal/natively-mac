import Foundation

/// Represents a semantically chunked text segment with an optional float embedding vector for RAG.
public struct VectorChunk: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let meetingId: String?
    public let chunkIndex: Int
    public let text: String
    public let embedding: [Float]?
    public let timestampMs: Int64
    
    public init(
        id: String = UUID().uuidString,
        meetingId: String? = nil,
        chunkIndex: Int = 0,
        text: String,
        embedding: [Float]? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.meetingId = meetingId
        self.chunkIndex = chunkIndex
        self.text = text
        self.embedding = embedding
        self.timestampMs = timestampMs
    }
}
