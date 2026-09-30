import Foundation
import WhisperKit
import NativelyCore

// Retroactive Sendable conformance for WhisperKit in Swift 6 concurrency mode
extension WhisperKit: @retroactive @unchecked Sendable {}

public struct WhisperSegment: Sendable, Equatable {
    public let text: String
    public let startMs: Int64
    public let endMs: Int64
    public let confidence: Float

    public init(text: String, startMs: Int64, endMs: Int64, confidence: Float = 1.0) {
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.confidence = confidence
    }
}

import CoreML

public actor WhisperTranscriptionService {
    public enum ModelVariant: String, Sendable, CaseIterable {
        case tiny = "openai_whisper-tiny"
        case base = "openai_whisper-base"
        case small = "openai_whisper-small"
    }

    private var whisperKit: WhisperKit?
    private var isInitialized = false
    public let modelVariant: ModelVariant

    public init(modelVariant: ModelVariant = .base) {
        self.modelVariant = modelVariant
    }

    public func initialize() async throws {
        guard !isInitialized else { return }
        // CoreML on Apple Silicon M4 / macOS Sequoia/27 crashes with SIGSEGV in
        // MLE5ProgramLibraryOnDeviceAOTCompilationImpl when using Neural Engine (.all or .cpuAndNeuralEngine).
        // By explicitly forcing .cpuAndGPU, CoreML uses Metal GPU compute instead of MLE5 ANE AOT compilation,
        // which avoids the crash and runs extremely fast on Apple Silicon GPUs.
        let computeOptions = ModelComputeOptions(
            melCompute: .cpuAndGPU,
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU,
            prefillCompute: .cpuAndGPU
        )
        let pipe = try await WhisperKit(
            model: modelVariant.rawValue,
            computeOptions: computeOptions,
            download: true
        )
        self.whisperKit = pipe
        self.isInitialized = true
    }

    public func transcribe(audioSamples: [Float]) async throws -> [WhisperSegment] {
        guard !audioSamples.isEmpty else { return [] }

        guard let whisperKit = self.whisperKit else {
            try await initialize()
            return try await transcribe(audioSamples: audioSamples)
        }

        let results = try await whisperKit.transcribe(audioArray: audioSamples)

        var segments: [WhisperSegment] = []
        for result in results {
            for segment in result.segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let startMs = Int64(segment.start * 1000)
                let endMs = Int64(segment.end * 1000)
                let confidence = segment.avgLogprob > -1.0 ? 1.0 : max(0.0, 1.0 + segment.avgLogprob)
                segments.append(WhisperSegment(text: text, startMs: startMs, endMs: endMs, confidence: Float(confidence)))
            }
        }
        return segments
    }
}
