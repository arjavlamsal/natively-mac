import Foundation
import AVFoundation

/// Represents a detected audio hardware device (Microphone or Audio Interface).
public struct AudioDeviceInfo: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let isBuiltIn: Bool
    public let isBluetooth: Bool
    
    public init(
        id: String,
        name: String,
        isDefault: Bool = false,
        isBuiltIn: Bool = false,
        isBluetooth: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isBuiltIn = isBuiltIn
        self.isBluetooth = isBluetooth
    }
}

/// Discovers, enumerates, and monitors audio input and output devices on macOS.
public final class AudioDeviceManager: @unchecked Sendable {
    public static let shared = AudioDeviceManager()
    
    public init() {}
    
    /// Discovers all available microphone input devices.
    public func getAvailableMicrophones() -> [AudioDeviceInfo] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        let defaultDevice = AVCaptureDevice.default(for: .audio)
        
        if devices.isEmpty {
            // Fallback: Default system microphone
            return [
                AudioDeviceInfo(
                    id: "default",
                    name: defaultDevice?.localizedName ?? "Default Microphone",
                    isDefault: true,
                    isBuiltIn: true
                )
            ]
        }
        
        return devices.map { device in
            let isDefault = (device.uniqueID == defaultDevice?.uniqueID)
            let isBuiltIn = device.localizedName.lowercased().contains("built-in") ||
                            device.localizedName.lowercased().contains("internal") ||
                            device.deviceType == .microphone
            let isBluetooth = device.localizedName.lowercased().contains("airpods") ||
                              device.localizedName.lowercased().contains("bluetooth")
            
            return AudioDeviceInfo(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: isDefault,
                isBuiltIn: isBuiltIn,
                isBluetooth: isBluetooth
            )
        }
    }
    
    /// Discovers system audio channels / loopback sources.
    public func getSystemAudioSources() -> [AudioDeviceInfo] {
        return [
            AudioDeviceInfo(
                id: "screencapturekit-system",
                name: "System Audio Loopback (ScreenCaptureKit Direct)",
                isDefault: true,
                isBuiltIn: true
            )
        ]
    }
}
