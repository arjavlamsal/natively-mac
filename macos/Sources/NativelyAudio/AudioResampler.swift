import Foundation
import AVFoundation

public enum AudioResamplerError: Error, LocalizedError {
    case unsupportedFormat(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let msg):
            return "Unsupported audio format: \(msg)"
        case .conversionFailed(let msg):
            return "Audio conversion failed: \(msg)"
        }
    }
}

public final class AudioResampler: @unchecked Sendable {
    public static let targetSampleRate: Double = 16000.0
    public static let targetChannelCount: AVAudioChannelCount = 1

    public let targetFormat: AVAudioFormat

    private var converter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?

    public init() {
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: Self.targetChannelCount,
            interleaved: false
        )!
    }

    public func resample(buffer: AVAudioPCMBuffer) throws -> [Float] {
        let inputFormat = buffer.format

        // Fast-path: already in 16kHz mono float32
        if inputFormat.sampleRate == Self.targetSampleRate && inputFormat.channelCount == Self.targetChannelCount,
           inputFormat.commonFormat == .pcmFormatFloat32,
           let channelData = buffer.floatChannelData {
            let frameLength = Int(buffer.frameLength)
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }

        // Initialize or update converter if input format changed
        if converter == nil || lastInputFormat != inputFormat {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw AudioResamplerError.unsupportedFormat("Cannot create converter from \(inputFormat) to \(targetFormat)")
            }
            newConverter.primeMethod = .none
            self.converter = newConverter
            self.lastInputFormat = inputFormat
        }

        guard let converter = self.converter else {
            throw AudioResamplerError.conversionFailed("Converter not initialized")
        }

        // Calculate expected output frame capacity based on sample rate ratio
        let ratio = Self.targetSampleRate / inputFormat.sampleRate
        let estimatedOutputFrames = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedOutputFrames) else {
            throw AudioResamplerError.conversionFailed("Could not allocate output buffer")
        }

        var isInputConsumed = false
        var conversionError: NSError?

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if isInputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            isInputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)

        if let error = conversionError {
            throw AudioResamplerError.conversionFailed(error.localizedDescription)
        }

        guard let floatData = outputBuffer.floatChannelData else {
            throw AudioResamplerError.conversionFailed("Output buffer does not contain float channel data")
        }

        let outputFrames = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: floatData[0], count: outputFrames))
    }
}
