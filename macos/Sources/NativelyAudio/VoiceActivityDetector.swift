import Foundation
import Accelerate

public final class VoiceActivityDetector: Sendable {
    public let energyThresholdDB: Float
    public let minSilenceDurationMs: Int64

    public init(energyThresholdDB: Float = -45.0, minSilenceDurationMs: Int64 = 800) {
        self.energyThresholdDB = energyThresholdDB
        self.minSilenceDurationMs = minSilenceDurationMs
    }

    /// Calculates the Root Mean Square (RMS) energy in decibels relative to full scale (dBFS).
    public func calculateRMS_dBFS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return -100.0 }

        var rms: Float = 0.0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        guard rms > 0.000001 else { return -100.0 }
        let db = 20.0 * log10(rms)
        return max(-100.0, min(0.0, db))
    }

    /// Determines whether the provided audio chunk contains audible voice activity.
    public func containsVoice(samples: [Float]) -> Bool {
        let db = calculateRMS_dBFS(samples: samples)
        return db >= energyThresholdDB
    }
}
