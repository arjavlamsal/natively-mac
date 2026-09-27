import Foundation
import AVFoundation

public enum AudioChannel: String, Sendable, Codable {
    case microphone = "microphone"
    case systemLoopback = "systemLoopback"

    public var defaultSpeakerLabel: String {
        switch self {
        case .microphone:
            return "You"
        case .systemLoopback:
            return "Interviewer"
        }
    }
}

public struct AudioChunk: Sendable {
    public let channel: AudioChannel
    public let speakerLabel: String
    public let samples: [Float]
    public let sampleRate: Double
    public let timestampMs: Int64

    public init(
        channel: AudioChannel,
        speakerLabel: String? = nil,
        samples: [Float],
        sampleRate: Double = 16000.0,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.channel = channel
        self.speakerLabel = speakerLabel ?? channel.defaultSpeakerLabel
        self.samples = samples
        self.sampleRate = sampleRate
        self.timestampMs = timestampMs
    }

    public var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / sampleRate
    }
}
