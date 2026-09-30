import Testing
import Foundation
@testable import NativelyCore
@testable import NativelyDatabase
@testable import NativelyRAG

@Suite("NativelyRAG Pipeline Tests")
struct RAGPipelineTests {
    
    @Test("AccelerateVectorEngine calculates precise cosine similarity and normalization")
    func testAccelerateMath() {
        let v1: [Float] = [1.0, 0.0, 0.0]
        let v2: [Float] = [1.0, 0.0, 0.0]
        let v3: [Float] = [0.0, 1.0, 0.0]
        let v4: [Float] = [-1.0, 0.0, 0.0]
        
        let simIdentical = AccelerateVectorEngine.cosineSimilarity(v1, v2)
        let simOrthogonal = AccelerateVectorEngine.cosineSimilarity(v1, v3)
        let simOpposite = AccelerateVectorEngine.cosineSimilarity(v1, v4)
        
        #expect(abs(simIdentical - 1.0) < 0.0001)
        #expect(abs(simOrthogonal - 0.0) < 0.0001)
        #expect(abs(simOpposite - (-1.0)) < 0.0001)
        
        let unnormalized: [Float] = [3.0, 4.0]
        let normalized = AccelerateVectorEngine.normalize(unnormalized)
        let norm = AccelerateVectorEngine.euclideanNorm(normalized)
        #expect(abs(norm - 1.0) < 0.0001)
    }
    
    @Test("SemanticChunker groups conversation turns without breaking speaker units")
    func testSemanticChunker() {
        let turns = [
            TranscriptTurn(meetingId: "m1", speaker: "Interviewer", content: "Can you tell me about your background in systems engineering?", timestampMs: 1000),
            TranscriptTurn(meetingId: "m1", speaker: "You", content: "Sure, I have spent the last five years working on high-throughput distributed databases and native macOS client applications.", timestampMs: 2000),
            TranscriptTurn(meetingId: "m1", speaker: "Interviewer", content: "That is great. How do you approach concurrency and thread safety?", timestampMs: 3000),
            TranscriptTurn(meetingId: "m1", speaker: "You", content: "I prefer actor-based concurrency and structured tasks with Swift 6 strict checking to prevent data races.", timestampMs: 4000)
        ]
        
        let chunks = SemanticChunker.chunkTranscripts(turns, maxWordsPerChunk: 25, overlapTurns: 1)
        #expect(chunks.count >= 2)
        #expect(chunks[0].meetingId == "m1")
        #expect(chunks[0].text.contains("Interviewer:"))
    }
    
    @Test("RAGRetriever ranks vector chunks by similarity and recency in AppDatabase")
    func testRetrieverEndToEnd() throws {
        let db = try AppDatabase.makeInMemory()
        let retriever = RAGRetriever(database: db)
        
        let meetingId = "m-test-rag"
        try db.saveMeeting(Meeting(id: meetingId, title: "RAG Test Meeting"))
        let chunk1 = VectorChunk(
            id: "c1",
            meetingId: meetingId,
            chunkIndex: 0,
            text: "We discussed using Swift 6 actors and GRDB SQLite for storage.",
            embedding: [0.9, 0.1, 0.0],
            timestampMs: 1000
        )
        let chunk2 = VectorChunk(
            id: "c2",
            meetingId: meetingId,
            chunkIndex: 1,
            text: "The audio resampler converts 48kHz stereo to 16kHz mono.",
            embedding: [0.0, 0.9, 0.1],
            timestampMs: 2000
        )
        let chunk3 = VectorChunk(
            id: "c3",
            meetingId: meetingId,
            chunkIndex: 2,
            text: "Compensation discussion and equity refresh schedule.",
            embedding: [0.0, 0.0, 0.9],
            timestampMs: 3000
        )
        
        try db.saveVectorChunks([chunk1, chunk2, chunk3])
        
        // Query for database & Swift
        let queryEmbedding: [Float] = [0.85, 0.15, 0.0]
        let results = try retriever.retrieveSimilar(queryEmbedding: queryEmbedding, meetingId: meetingId, topK: 2, minSimilarity: 0.1)
        
        #expect(results.count == 2)
        #expect(results[0].chunk.id == "c1")
        #expect(results[0].similarity > 0.8)
        
        // Test lexical search
        let lexicalResults = try retriever.searchLexical(query: "resampler audio", meetingId: meetingId)
        #expect(!lexicalResults.isEmpty)
        #expect(lexicalResults[0].id == "c2")
    }

    @Test("DocumentIngestionService parses and chunks reference files into AppDatabase")
    func testDocumentIngestion() async throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "m-doc-ingest"
        try db.saveMeeting(Meeting(id: meetingId, title: "Document Ingestion Meeting"))

        let ingestion = DocumentIngestionService(database: db)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample_system_design.md")
        let sampleContent = """
        # System Architecture
        The native macOS client replaces Electron with Swift 6 AppKit and SwiftUI.
        Memory footprint drops from 800MB to under 45MB.
        ScreenCaptureKit provides 60fps frame streaming with hardware-accelerated metal blending.
        WhisperKit runs locally on Apple Silicon Neural Engine with zero cloud roundtrip latency.
        """
        try sampleContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let count = try await ingestion.ingestDocument(at: tempURL, meetingId: meetingId)
        #expect(count >= 1)

        let savedChunks = try db.fetchVectorChunks(meetingId: meetingId)
        #expect(savedChunks.count == count)
        #expect(savedChunks[0].text.contains("[sample_system_design.md]"))
        #expect(savedChunks[0].text.contains("System Architecture"))
    }

    @Test("DocumentIngestionService handles empty files and alternative encodings gracefully")
    func testDocumentIngestionEdgeCases() async throws {
        let db = try AppDatabase.makeInMemory()
        let ingestion = DocumentIngestionService(database: db)

        // 1. Empty file
        let emptyURL = FileManager.default.temporaryDirectory.appendingPathComponent("empty_notes.txt")
        try "".write(to: emptyURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: emptyURL) }

        let emptyCount = try await ingestion.ingestDocument(at: emptyURL, meetingId: "m-empty")
        #expect(emptyCount == 0)

        // 2. ISO-Latin-1 encoding
        let meetingId = "m-latin"
        try db.saveMeeting(Meeting(id: meetingId, title: "Latin Notes Meeting"))
        let latinURL = FileManager.default.temporaryDirectory.appendingPathComponent("latin_notes.txt")
        let latinData = "Resume: François Müller with résumé and café experience.".data(using: .isoLatin1)!
        try latinData.write(to: latinURL)
        defer { try? FileManager.default.removeItem(at: latinURL) }

        let latinCount = try await ingestion.ingestDocument(at: latinURL, meetingId: meetingId)
        #expect(latinCount >= 1)
    }
}
