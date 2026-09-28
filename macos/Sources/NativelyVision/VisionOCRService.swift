import Foundation
import CoreGraphics
import Vision

public enum VisionOCRError: Error, LocalizedError {
    case processingFailed(String)
    case invalidImageData
    
    public var errorDescription: String? {
        switch self {
        case .processingFailed(let msg): return "Vision OCR processing failed: \(msg)"
        case .invalidImageData: return "Image data could not be parsed for OCR."
        }
    }
}

/// Hardware-accelerated Optical Character Recognition powered by Apple Neural Engine and Vision.framework.
public final class VisionOCRService: Sendable {
    
    public enum RecognitionMode: Sendable {
        /// Highest accuracy Neural Engine recognition (sub-35ms).
        case accurate
        /// Lower-latency character recognition (sub-15ms).
        case fast
    }
    
    public init() {}
    
    /// Recognizes text within a CoreGraphics image.
    public func recognizeText(
        in cgImage: CGImage,
        mode: RecognitionMode = .accurate,
        languages: [String] = ["en-US"]
    ) async throws -> OCRResult {
        let startTime = DispatchTime.now()
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: VisionOCRError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    let endTime = DispatchTime.now()
                    let elapsedMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
                    continuation.resume(returning: OCRResult(fullText: "", lines: [], averageConfidence: 1.0, executionDurationMs: elapsedMs))
                    return
                }
                
                var lines: [OCRTextLine] = []
                var textAccumulator: [String] = []
                var totalConfidence: Float = 0.0
                
                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let lineText = candidate.string
                    textAccumulator.append(lineText)
                    totalConfidence += candidate.confidence
                    
                    let line = OCRTextLine(
                        text: lineText,
                        confidence: candidate.confidence,
                        normalizedBoundingBox: obs.boundingBox
                    )
                    lines.append(line)
                }
                
                let endTime = DispatchTime.now()
                let elapsedMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
                let avgConfidence = lines.isEmpty ? 1.0 : (totalConfidence / Float(lines.count))
                let fullText = textAccumulator.joined(separator: "\n")
                
                continuation.resume(returning: OCRResult(
                    fullText: fullText,
                    lines: lines,
                    averageConfidence: avgConfidence,
                    executionDurationMs: elapsedMs
                ))
            }
            
            request.recognitionLevel = (mode == .accurate) ? .accurate : .fast
            request.recognitionLanguages = languages
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionOCRError.processingFailed(error.localizedDescription))
            }
        }
    }
}
