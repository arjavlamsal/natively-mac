import Foundation
import Speech
import AVFoundation
import os
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
        
        let lock = OSAllocatedUnfairLock(initialState: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let finish: @Sendable (Result<[WhisperSegment], Error>) -> Void = { result in
                let shouldResume = lock.withLock { hasResumed -> Bool in
                    if !hasResumed {
                        hasResumed = true
                        return true
                    }
                    return false
                }
                if shouldResume {
                    continuation.resume(with: result)
                }
            }
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                if error != nil {
                    finish(.success([]))
                    return
                }
                
                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription
                    let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard !text.isEmpty else {
                        finish(.success([]))
                        return
                    }
                    
                    let durationMs = Int64(Double(audioSamples.count) / 16.0)
                    let segment = WhisperSegment(
                        text: text,
                        startMs: 0,
                        endMs: durationMs,
                        confidence: 1.0
                    )
                    finish(.success([segment]))
                }
            }
            
            _ = task
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
                channelData[0].update(from: base, count: samples.count)
            }
        }
        return buffer
    }
}
