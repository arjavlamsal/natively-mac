import Foundation
import NativelyCore
import NativelyDatabase

/// Represents a candidate chunk scored by similarity and recency.
public struct ScoredChunk: Sendable, Identifiable {
    public var id: String { chunk.id }
    public let chunk: VectorChunk
    public let similarity: Float
    public let combinedScore: Float
    
    public init(chunk: VectorChunk, similarity: Float, combinedScore: Float) {
        self.chunk = chunk
        self.similarity = similarity
        self.combinedScore = combinedScore
    }
}

/// Orchestrates vector and lexical retrieval over meeting history and documents.
public final class RAGRetriever: Sendable {
    private let database: AppDatabase
    
    public init(database: AppDatabase = .shared) {
        self.database = database
    }
    
    /// Retrieves the top-K most relevant chunks using hardware-accelerated cosine similarity and recency re-ranking.
    public func retrieveSimilar(
        queryEmbedding: [Float],
        meetingId: String? = nil,
        topK: Int = 5,
        minSimilarity: Float = 0.2,
        recencyWeight: Float = 0.2
    ) throws -> [ScoredChunk] {
        let chunks = try database.fetchVectorChunks(meetingId: meetingId)
        guard !chunks.isEmpty else { return [] }
        
        let now = Date().timeIntervalSince1970 * 1000
        var scored: [ScoredChunk] = []
        
        for chunk in chunks {
            guard let embedding = chunk.embedding, embedding.count == queryEmbedding.count else {
                continue
            }
            
            let similarity = AccelerateVectorEngine.cosineSimilarity(queryEmbedding, embedding)
            if similarity >= minSimilarity {
                // Calculate recency decay factor (half-life of 7 days)
                let ageHours = max(0, (now - Double(chunk.timestampMs)) / (1000 * 3600))
                let recencyFactor = Float(exp(-ageHours / 168.0)) // 168 hours = 7 days
                
                let combined = (1.0 - recencyWeight) * similarity + recencyWeight * recencyFactor
                scored.append(ScoredChunk(chunk: chunk, similarity: similarity, combinedScore: combined))
            }
        }
        
        // Sort descending by combined score
        scored.sort { $0.combinedScore > $1.combinedScore }
        return Array(scored.prefix(topK))
    }
    
    /// Fallback lexical keyword search when vectors are not available.
    public func searchLexical(
        query: String,
        meetingId: String? = nil,
        topK: Int = 5
    ) throws -> [VectorChunk] {
        let chunks = try database.fetchVectorChunks(meetingId: meetingId)
        let queryTokens = Set(query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
        guard !queryTokens.isEmpty else { return Array(chunks.prefix(topK)) }
        
        var scored: [(VectorChunk, Int)] = []
        for chunk in chunks {
            let chunkTextLower = chunk.text.lowercased()
            var matches = 0
            for token in queryTokens {
                if chunkTextLower.contains(token) {
                    matches += 1
                }
            }
            if matches > 0 {
                scored.append((chunk, matches))
            }
        }
        
        scored.sort { $0.1 > $1.1 }
        return scored.prefix(topK).map { $0.0 }
    }
    
    /// Assembles retrieved chunks into a clean Markdown context block for prompt grounding.
    public static func formatContextBlock(chunks: [VectorChunk]) -> String {
        guard !chunks.isEmpty else { return "" }
        var result = "### RELEVANT MEETING CONTEXT:\n"
        for (idx, chunk) in chunks.enumerated() {
            result += "\n[Source \(idx + 1)]:\n\(chunk.text)\n"
        }
        return result
    }
}
