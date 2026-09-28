import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

public enum ScreenCaptureError: Error, LocalizedError {
    case permissionDenied
    case noDisplaysAvailable
    case displayNotFound(CGDirectDisplayID)
    case captureFailed(String)
    case invalidCropRect(CGRect)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is denied. Enable it in macOS System Settings > Privacy & Security > Screen Recording."
        case .noDisplaysAvailable:
            return "No active displays were found for screen capture."
        case .displayNotFound(let id):
            return "Display with ID \(id) could not be located in shareable content."
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .invalidCropRect(let rect):
            return "The specified crop area \(rect) is outside valid display bounds."
        }
    }
}

/// Service providing sub-15ms hardware-accelerated screen capture via Apple's ScreenCaptureKit.
public final class ScreenCaptureService: @unchecked Sendable {
    
    public init() {}
    
    /// Checks whether macOS Screen Recording permission has been granted.
    public static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    /// Requests Screen Recording permission from macOS if not already granted.
    @discardableResult
    public static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
    
    /// Captures the main/active display.
    public func captureMainDisplay(showsCursor: Bool = false) async throws -> CGImage {
        let mainDisplayID = CGMainDisplayID()
        return try await captureDisplay(displayID: mainDisplayID, showsCursor: showsCursor)
    }
    
    /// Captures a specific display by its CoreGraphics display ID.
    public func captureDisplay(
        displayID: CGDirectDisplayID,
        showsCursor: Bool = false
    ) async throws -> CGImage {
        guard Self.hasPermission else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.displayNotFound(displayID)
        }
        
        // Exclude our own application from the capture filter as an additional guard
        let myPID = ProcessInfo.processInfo.processIdentifier
        let excludedApps = content.applications.filter { $0.processID == myPID }
        
        let filter = SCContentFilter(display: scDisplay, excludingApplications: excludedApps, exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        let pixelWidth = CGDisplayPixelsWide(displayID)
        let pixelHeight = CGDisplayPixelsHigh(displayID)
        
        config.width = pixelWidth > 0 ? pixelWidth : scDisplay.width * 2
        config.height = pixelHeight > 0 ? pixelHeight : scDisplay.height * 2
        config.showsCursor = showsCursor
        
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            return image
        } catch {
            throw ScreenCaptureError.captureFailed(error.localizedDescription)
        }
    }
    
    /// Captures a specific rectangular area in global screen coordinates.
    /// Finds the intersecting display, captures it, and performs a pixel-accurate crop.
    public func captureRect(
        _ globalRect: CGRect,
        showsCursor: Bool = false
    ) async throws -> CGImage {
        guard Self.hasPermission else {
            throw ScreenCaptureError.permissionDenied
        }
        
        guard globalRect.width > 2 && globalRect.height > 2 else {
            throw ScreenCaptureError.invalidCropRect(globalRect)
        }
        
        // Identify which display contains or intersects the selection center
        let centerX = globalRect.midX
        let centerY = globalRect.midY
        let targetPoint = CGPoint(x: centerX, y: centerY)
        
        var displayCount: UInt32 = 0
        CGGetDisplaysWithPoint(targetPoint, 0, nil, &displayCount)
        
        var matchingDisplayID = CGMainDisplayID()
        if displayCount > 0 {
            var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
            CGGetDisplaysWithPoint(targetPoint, displayCount, &displayIDs, &displayCount)
            if let first = displayIDs.first {
                matchingDisplayID = first
            }
        }
        
        // Capture the full display image
        let fullImage = try await captureDisplay(displayID: matchingDisplayID, showsCursor: showsCursor)
        let displayBounds = CGDisplayBounds(matchingDisplayID)
        
        // Crop down to the selected rectangle
        return try ImageProcessor.crop(
            cgImage: fullImage,
            displayLogicalBounds: displayBounds,
            selectionLogicalRect: globalRect
        )
    }
}
