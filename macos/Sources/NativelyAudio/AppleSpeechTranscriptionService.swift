import Foundation
import Speech
import AVFoundation
import NativelyCore

/// Native Apple Speech transcription service using macOS Speech.framework (`SFSpeechRecognizer`).
/// Provides instant, zero-download, on-device transcription for 50+ languages.
public actor AppleSpeechTranscriptionService {
    private let recognizer: SFSpeechRecognizer?
    private let audioFormat: AVAudioFormat
    
    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    }
    
    /// Checks if Apple Speech recognition is available on this system.
    public func isAvailable() -> Bool {
        return recognizer?.isAvailable ?? false
    }
    
    /// Requests speech recognition permission.
    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Transcribes an array of 16kHz mono float32 audio samples.
    public func transcribe(audioSamples: [Float]) async throws -> [WhisperSegment] {
        guard !audioSamples.isEmpty else { return [] }
        guard let recognizer = self.recognizer, recognizer.isAvailable else {
            return []
        }
        
        // Convert Float array to AVAudioPCMBuffer
        guard let pcmBuffer = createPCMBuffer(from: audioSamples) else {
            return []
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        request.append(pcmBuffer)
        request.endAudio()
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognizer.recognitionTask(with: request) { result, error in
                if error != nil {
                    if !hasResumed {
                        hasResumed = true
                        // SFSpeechRecognizer often returns errors on silence or empty buffers; return empty segments gracefully
                        continuation.resume(returning: [])
                    }
                    return
                }
                
                if let result = result, result.isFinal {
                    if !hasResumed {
                        hasResumed = true
                        let transcription = result.bestTranscription
                        let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard !text.isEmpty else {
                            continuation.resume(returning: [])
                            return
                        }
                        
                        let durationMs = Int64(Double(audioSamples.count) / 16.0)
                        let segment = WhisperSegment(
                            text: text,
                            startMs: 0,
                            endMs: durationMs,
                            confidence: 1.0
                        )
                        continuation.resume(returning: [segment])
                    }
                }
            }
        }
    }
    
    private func createPCMBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                channelData[0].initialize(from: base, count: samples.count)
            }
        }
        return buffer
    }
}
