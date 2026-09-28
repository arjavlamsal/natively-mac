import Foundation
import NativelyCore

/// Splits long text and conversation transcripts into coherent, semantically bounded vector chunks.
public enum SemanticChunker {
    
    /// Chunks a sequence of transcript turns into context windows respecting speaker boundaries.
    public static func chunkTranscripts(
        _ turns: [TranscriptTurn],
        maxWordsPerChunk: Int = 120,
        overlapTurns: Int = 1
    ) -> [VectorChunk] {
        guard !turns.isEmpty else { return [] }
        
        var chunks: [VectorChunk] = []
        var currentTurns: [TranscriptTurn] = []
        var currentWordCount = 0
        var chunkIndex = 0
        let meetingId = turns.first?.meetingId
        
        for turn in turns {
            let turnWords = turn.content.split(whereSeparator: \.isWhitespace).count
            
            if currentWordCount + turnWords > maxWordsPerChunk && !currentTurns.isEmpty {
                // Form chunk
                let chunkText = formatTurns(currentTurns)
                let firstTimestamp = currentTurns.first?.timestampMs ?? Int64(Date().timeIntervalSince1970 * 1000)
                chunks.append(VectorChunk(
                    meetingId: meetingId,
                    chunkIndex: chunkIndex,
                    text: chunkText,
                    timestampMs: firstTimestamp
                ))
                chunkIndex += 1
                
                // Carry over overlap turns
                let carryOver = Array(currentTurns.suffix(overlapTurns))
                currentTurns = carryOver
                currentWordCount = carryOver.reduce(0) { $0 + $1.content.split(whereSeparator: \.isWhitespace).count }
            }
            
            currentTurns.append(turn)
            currentWordCount += turnWords
        }
        
        // Append trailing chunk
        if !currentTurns.isEmpty {
            let chunkText = formatTurns(currentTurns)
            let firstTimestamp = currentTurns.first?.timestampMs ?? Int64(Date().timeIntervalSince1970 * 1000)
            chunks.append(VectorChunk(
                meetingId: meetingId,
                chunkIndex: chunkIndex,
                text: chunkText,
                timestampMs: firstTimestamp
            ))
        }
        
        return chunks
    }
    
    /// Chunks arbitrary text (documents, DOM text) by paragraph boundaries with sliding window overlap.
    public static func chunkText(
        _ text: String,
        meetingId: String? = nil,
        maxWordsPerChunk: Int = 150,
        overlapWords: Int = 25
    ) -> [VectorChunk] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !paragraphs.isEmpty else {
            let words = text.split(whereSeparator: \.isWhitespace)
            if words.isEmpty { return [] }
            return [VectorChunk(meetingId: meetingId, chunkIndex: 0, text: text)]
        }
        
        var chunks: [VectorChunk] = []
        var currentParagraphs: [String] = []
        var currentWordCount = 0
        var chunkIndex = 0
        
        for para in paragraphs {
            let words = para.split(whereSeparator: \.isWhitespace).count
            if currentWordCount + words > maxWordsPerChunk && !currentParagraphs.isEmpty {
                let chunkContent = currentParagraphs.joined(separator: "\n\n")
                chunks.append(VectorChunk(
                    meetingId: meetingId,
                    chunkIndex: chunkIndex,
                    text: chunkContent
                ))
                chunkIndex += 1
                
                currentParagraphs = []
                currentWordCount = 0
            }
            currentParagraphs.append(para)
            currentWordCount += words
        }
        
        if !currentParagraphs.isEmpty {
            chunks.append(VectorChunk(
                meetingId: meetingId,
                chunkIndex: chunkIndex,
                text: currentParagraphs.joined(separator: "\n\n")
            ))
        }
        
        return chunks
    }
    
    private static func formatTurns(_ turns: [TranscriptTurn]) -> String {
        turns.map { "\($0.speaker): \($0.content)" }.joined(separator: "\n")
    }
}
