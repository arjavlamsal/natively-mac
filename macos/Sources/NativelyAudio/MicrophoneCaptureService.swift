import Foundation
import AVFoundation

public enum MicrophoneCaptureError: Error, LocalizedError {
    case inputNodeUnavailable
    case engineStartFailed(String)

    public var errorDescription: String? {
        switch self {
        case .inputNodeUnavailable:
            return "Microphone input node is unavailable."
        case .engineStartFailed(let msg):
            return "Failed to start audio engine: \(msg)"
        }
    }
}

public final class MicrophoneCaptureService: @unchecked Sendable {
    public typealias ChunkHandler = @Sendable (AudioChunk) -> Void

    private let engine = AVAudioEngine()
    private let resampler = AudioResampler()
    private var chunkHandler: ChunkHandler?
    private let lock = NSLock()
    private var isRunning = false

    public init() {}

    public func setChunkHandler(_ handler: @escaping ChunkHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.chunkHandler = handler
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw MicrophoneCaptureError.inputNodeUnavailable
        }

        // Buffer size: ~100ms chunks (e.g. 4800 frames at 48kHz, 1600 frames at 16kHz)
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            do {
                let samples16k = try self.resampler.resample(buffer: buffer)
                let chunk = AudioChunk(
                    channel: .microphone,
                    speakerLabel: "You",
                    samples: samples16k,
                    sampleRate: AudioResampler.targetSampleRate
                )
                self.lock.lock()
                let handler = self.chunkHandler
                self.lock.unlock()
                handler?(chunk)
            } catch {
                // Silently skip corrupted frame in production
            }
        }

        do {
            try engine.start()
            isRunning = true
        } catch {
            throw MicrophoneCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    /// Re-anchors audio tap after route change (e.g. AirPods switch).
    public func reconfigure() throws {
        lock.lock()
        let wasRunning = self.isRunning
        lock.unlock()

        if wasRunning {
            stop()
            try start()
        }
    }

    public var isCapturing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }
}
