import Foundation
import PDFKit
import NativelyCore
import NativelyDatabase

/// Handles extraction, chunking, and vector persistence for user-uploaded documents (PDF, TXT, Markdown)
/// matching Natively's reference file ingestion architecture.
public final class DocumentIngestionService: Sendable {
    private let database: AppDatabase
    
    public init(database: AppDatabase = .shared) {
        self.database = database
    }
    
    /// Ingests a local file (PDF, TXT, MD, Code) into vector chunks stored in AppDatabase.
    public func ingestDocument(at url: URL, meetingId: String? = nil) async throws -> Int {
        let text: String
        let ext = url.pathExtension.lowercased()
        
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(domain: "DocumentIngestion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document"])
            }
            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            text = fullText
        } else {
            text = try String(contentsOf: url, encoding: .utf8)
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        
        let filename = url.lastPathComponent
        let chunks = SemanticChunker.chunkText(trimmed, meetingId: meetingId, maxWordsPerChunk: 140, overlapWords: 20)
        
        for chunk in chunks {
            let enrichedChunk = VectorChunk(
                id: chunk.id,
                meetingId: chunk.meetingId,
                chunkIndex: chunk.chunkIndex,
                text: "[\(filename)]: \(chunk.text)",
                embedding: chunk.embedding,
                timestampMs: chunk.timestampMs
            )
            try database.saveVectorChunk(enrichedChunk)
        }
        
        return chunks.count
    }
}
