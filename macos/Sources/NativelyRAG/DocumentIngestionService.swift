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
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Guard against unbounded file sizes (> 50 MB)
        let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resources?.fileSize, fileSize > 50 * 1024 * 1024 {
            throw NSError(
                domain: "DocumentIngestion",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "File exceeds 50 MB limit. Please select a smaller document."]
            )
        }
        
        let text: String
        let ext = url.pathExtension.lowercased()
        
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(domain: "DocumentIngestion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document"])
            }
            var fullText = ""
            let maxPages = min(pdf.pageCount, 500)
            for i in 0..<maxPages {
                if let page = pdf.page(at: i), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            text = fullText
        } else {
            // Attempt UTF-8, then fallback to ISO Latin / ASCII
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                text = utf8
            } else if let latin = try? String(contentsOf: url, encoding: .isoLatin1) {
                text = latin
            } else {
                text = try String(contentsOf: url, encoding: .ascii)
            }
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        
        let filename = url.lastPathComponent
        let chunks = SemanticChunker.chunkText(trimmed, meetingId: meetingId, maxWordsPerChunk: 140, overlapWords: 20)
        
        let enrichedChunks = chunks.map { chunk in
            VectorChunk(
                id: chunk.id,
                meetingId: chunk.meetingId,
                chunkIndex: chunk.chunkIndex,
                text: "[\(filename)]: \(chunk.text)",
                embedding: chunk.embedding,
                timestampMs: chunk.timestampMs
            )
        }
        
        try database.saveVectorChunks(enrichedChunks)
        return enrichedChunks.count
    }
}
