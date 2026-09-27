import Foundation
import ScreenCaptureKit
import AVFoundation

public enum SystemAudioCaptureError: Error, LocalizedError {
    case noDisplayAvailable
    case streamInitializationFailed(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "No active display found for ScreenCaptureKit audio tap."
        case .streamInitializationFailed(let msg):
            return "Failed to initialize ScreenCaptureKit audio stream: \(msg)"
        case .permissionDenied:
            return "Screen recording permission is required for system audio capture."
        }
    }
}

public final class SystemAudioCaptureService: NSObject, @unchecked Sendable, SCStreamOutput, SCStreamDelegate {
    public typealias ChunkHandler = @Sendable (AudioChunk) -> Void

    private var stream: SCStream?
    private var chunkHandler: ChunkHandler?
    private let lock = NSLock()
    private var isRunning = false
    private let audioQueue = DispatchQueue(label: "software.natively.system-audio-capture", qos: .userInteractive)

    public override init() {
        super.init()
    }

    private func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    public func setChunkHandler(_ handler: @escaping ChunkHandler) {
        synchronized {
            self.chunkHandler = handler
        }
    }

    public func start(excludingWindows: [SCWindow] = []) async throws {
        let alreadyRunning = synchronized { self.isRunning }
        guard !alreadyRunning else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: excludingWindows)
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(AudioResampler.targetSampleRate)
        config.channelCount = Int(AudioResampler.targetChannelCount)
        config.excludesCurrentProcessAudio = true

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await newStream.startCapture()

        synchronized {
            self.stream = newStream
            self.isRunning = true
        }
    }

    public func stop() async {
        let streamToStop: SCStream? = synchronized {
            guard self.isRunning, let s = self.stream else { return nil }
            self.isRunning = false
            self.stream = nil
            return s
        }

        if let streamToStop {
            try? await streamToStop.stopCapture()
        }
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let dataPointer = dataPointer else {
            return
        }

        var floatSamples: [Float] = []

        if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            // Audio data is 32-bit float
            let floatCount = totalLength / MemoryLayout<Float>.size
            let floatPtr = dataPointer.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }
            floatSamples = Array(UnsafeBufferPointer(start: floatPtr, count: floatCount))
        } else if asbd.pointee.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 && asbd.pointee.mBitsPerChannel == 16 {
            // Audio data is 16-bit signed integer PCM
            let int16Count = totalLength / MemoryLayout<Int16>.size
            let int16Ptr = dataPointer.withMemoryRebound(to: Int16.self, capacity: int16Count) { $0 }
            floatSamples = (0..<int16Count).map { Float(int16Ptr[$0]) / 32768.0 }
        }

        guard !floatSamples.isEmpty else { return }

        let chunk = AudioChunk(
            channel: .systemLoopback,
            speakerLabel: "Interviewer",
            samples: floatSamples,
            sampleRate: asbd.pointee.mSampleRate > 0 ? asbd.pointee.mSampleRate : AudioResampler.targetSampleRate
        )

        let handler = synchronized { self.chunkHandler }
        handler?(chunk)
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        synchronized {
            self.isRunning = false
            self.stream = nil
        }
    }

    public var isCapturing: Bool {
        synchronized { isRunning }
    }
}
