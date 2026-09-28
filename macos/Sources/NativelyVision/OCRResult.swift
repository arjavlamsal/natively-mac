import Foundation
import CoreGraphics

/// An individual line of text recognized by Apple's Vision framework.
public struct OCRTextLine: Sendable, Equatable {
    /// The recognized text string.
    public let text: String
    
    /// The recognition confidence score, normalized from 0.0 (uncertain) to 1.0 (certain).
    public let confidence: Float
    
    /// Normalized bounding box within the image (coordinates in [0, 1]).
    public let normalizedBoundingBox: CGRect
    
    public init(text: String, confidence: Float, normalizedBoundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.normalizedBoundingBox = normalizedBoundingBox
    }
}

/// The complete output of a Neural Engine Vision OCR pass.
public struct OCRResult: Sendable, Equatable {
    /// The concatenated full text extracted from the image.
    public let fullText: String
    
    /// The recognized lines in reading order.
    public let lines: [OCRTextLine]
    
    /// The arithmetic mean confidence across all recognized lines.
    public let averageConfidence: Float
    
    /// The processing time in milliseconds.
    public let executionDurationMs: Double
    
    /// True if no text was detected or text is purely whitespace.
    public var isEmpty: Bool {
        fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Estimated word count of the recognized text.
    public var wordCount: Int {
        let words = fullText.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return words.count
    }
    
    public init(
        fullText: String,
        lines: [OCRTextLine] = [],
        averageConfidence: Float = 1.0,
        executionDurationMs: Double = 0.0
    ) {
        self.fullText = fullText
        self.lines = lines
        self.averageConfidence = averageConfidence
        self.executionDurationMs = executionDurationMs
    }
    
    /// Empty placeholder result.
    public static let empty = OCRResult(fullText: "")
}
