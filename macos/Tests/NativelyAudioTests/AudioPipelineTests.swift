import Testing
import Foundation
import AVFoundation
@testable import NativelyCore
@testable import NativelyDatabase
@testable import NativelyAudio

@Suite("NativelyAudio Pipeline Tests")
struct AudioPipelineTests {
    @Test("AudioChunk duration and speaker label defaults")
    func testAudioChunk() {
        let samples = [Float](repeating: 0.0, count: 16000) // 1 second at 16kHz
        let micChunk = AudioChunk(channel: .microphone, samples: samples)
        #expect(micChunk.speakerLabel == "You")
        #expect(micChunk.durationSeconds == 1.0)

        let sysChunk = AudioChunk(channel: .systemLoopback, samples: samples)
        #expect(sysChunk.speakerLabel == "Interviewer")
        #expect(sysChunk.durationSeconds == 1.0)
    }

    @Test("VoiceActivityDetector detects speech vs silence")
    func testVoiceActivityDetector() {
        let vad = VoiceActivityDetector(energyThresholdDB: -45.0)

        // 1. Absolute silence
        let silence = [Float](repeating: 0.0, count: 1600)
        #expect(!vad.containsVoice(samples: silence))
        #expect(vad.calculateRMS_dBFS(samples: silence) <= -90.0)

        // 2. Synthetic audible signal (440Hz sine wave at amplitude 0.5)
        var tone = [Float](repeating: 0.0, count: 1600)
        for i in 0..<1600 {
            tone[i] = 0.5 * sin(2.0 * .pi * 440.0 * Float(i) / 16000.0)
        }
        #expect(vad.containsVoice(samples: tone))
        let toneDb = vad.calculateRMS_dBFS(samples: tone)
        #expect(toneDb > -15.0 && toneDb < 0.0)
    }

    @Test("AudioResampler converts 48kHz stereo to 16kHz mono")
    func testAudioResamplerConversion() throws {
        let resampler = AudioResampler()

        // Create a 48kHz stereo source buffer (0.1s = 4800 frames)
        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000.0,
            channels: 2,
            interleaved: false
        )!
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 4800) else {
            Issue.record("Failed to allocate source buffer")
            return
        }
        sourceBuffer.frameLength = 4800

        // Fill with a sine wave
        for ch in 0..<2 {
            let channelPtr = sourceBuffer.floatChannelData![ch]
            for i in 0..<4800 {
                channelPtr[i] = 0.5 * sin(2.0 * .pi * 440.0 * Float(i) / 48000.0)
            }
        }

        let resampled = try resampler.resample(buffer: sourceBuffer)

        // 0.1s at 16kHz should be ~1600 samples (mono)
        #expect(abs(resampled.count - 1600) <= 20)
    }

    @Test("AudioResampler fast path for 16kHz mono float32")
    func testAudioResamplerFastPath() throws {
        let resampler = AudioResampler()

        let format16k = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000.0,
            channels: 1,
            interleaved: false
        )!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format16k, frameCapacity: 1600) else {
            Issue.record("Failed to allocate 16kHz buffer")
            return
        }
        buffer.frameLength = 1600
        let ptr = buffer.floatChannelData![0]
        for i in 0..<1600 {
            ptr[i] = Float(i) / 1600.0
        }

        let result = try resampler.resample(buffer: buffer)
        #expect(result.count == 1600)
        #expect(result[0] == 0.0)
    }

    @Test("DualChannelAudioCoordinator chunk ingestion and speaker separation")
    func testDualChannelCoordinatorIngestion() async throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "m-dual-test"
        try db.saveMeeting(Meeting(id: meetingId, title: "Dual Channel Test Meeting"))

        let coordinator = DualChannelAudioCoordinator(database: db)

        // Create 0.5s chunks
        let tone440 = (0..<8000).map { 0.4 * sin(2.0 * .pi * 440.0 * Float($0) / 16000.0) }

        let micChunk = AudioChunk(channel: .microphone, samples: tone440, timestampMs: 1000)
        let sysChunk = AudioChunk(channel: .systemLoopback, samples: tone440, timestampMs: 2000)

        #expect(micChunk.channel == .microphone)
        #expect(micChunk.speakerLabel == "You")
        #expect(sysChunk.channel == .systemLoopback)
        #expect(sysChunk.speakerLabel == "Interviewer")

        await coordinator.ingestChunk(micChunk)
        await coordinator.ingestChunk(sysChunk)
    }
}
