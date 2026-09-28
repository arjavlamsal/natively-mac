import Foundation
import AppKit
import AVFoundation
import ApplicationServices
import CoreGraphics

/// Manages system permission checks and prompt flows for Screen Capture, Microphone, and Accessibility.
@MainActor
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    
    @Published public private(set) var hasScreenRecordingPermission: Bool = false
    @Published public private(set) var hasMicrophonePermission: Bool = false
    @Published public private(set) var hasAccessibilityPermission: Bool = false
    
    public init() {
        checkAllPermissions()
    }
    
    /// Re-evaluates current status of all required permissions.
    public func checkAllPermissions() {
        checkScreenRecordingPermission()
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }
    
    // MARK: - Screen Recording
    
    @discardableResult
    public func checkScreenRecordingPermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        self.hasScreenRecordingPermission = granted
        return granted
    }
    
    public func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
        checkScreenRecordingPermission()
    }
    
    // MARK: - Microphone
    
    @discardableResult
    public func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let granted = (status == .authorized)
        self.hasMicrophonePermission = granted
        return granted
    }
    
    public func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        self.hasMicrophonePermission = granted
        return granted
    }
    
    // MARK: - Accessibility
    
    @discardableResult
    public func checkAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        self.hasAccessibilityPermission = granted
        return granted
    }
    
    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        checkAccessibilityPermission()
    }
    
    // MARK: - System Settings Navigation
    
    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
