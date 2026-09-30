import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit
import ImageIO

public enum ScreenCaptureError: Error, LocalizedError {
    case permissionDenied
    case noDisplaysAvailable
    case displayNotFound(CGDirectDisplayID)
    case captureFailed(String)
    case invalidCropRect(CGRect)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen Recording permission is denied. Enable it in macOS System Settings > Privacy & Security > Screen & System Audio Recording."
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

/// Service providing sub-15ms hardware-accelerated screen capture via Apple's ScreenCaptureKit,
/// backed by a resilient system-level `/usr/sbin/screencapture` fallback pipeline.
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
    /// Uses ScreenCaptureKit as primary tier with automatic fallback to `/usr/sbin/screencapture`.
    public func captureDisplay(
        displayID: CGDirectDisplayID,
        showsCursor: Bool = false
    ) async throws -> CGImage {
        // Tier 1: ScreenCaptureKit
        do {
            return try await captureViaScreenCaptureKit(displayID: displayID, showsCursor: showsCursor)
        } catch {
            // Tier 2: Resilient macOS system CLI fallback
            do {
                return try await captureViaSystemCLI(displayID: displayID, rect: nil, showsCursor: showsCursor)
            } catch let fallbackError {
                if !Self.hasPermission {
                    throw ScreenCaptureError.permissionDenied
                }
                throw ScreenCaptureError.captureFailed("ScreenCaptureKit error: \(error.localizedDescription); Fallback error: \(fallbackError.localizedDescription)")
            }
        }
    }
    
    /// Captures a specific rectangular area in global CoreGraphics coordinates.
    /// Finds intersecting display, captures via ScreenCaptureKit + pixel crop,
    /// or falls back to pixel-exact `/usr/sbin/screencapture -R`.
    public func captureRect(
        _ globalRect: CGRect,
        showsCursor: Bool = false
    ) async throws -> CGImage {
        guard globalRect.width > 2 && globalRect.height > 2 else {
            throw ScreenCaptureError.invalidCropRect(globalRect)
        }
        
        // Attempt Tier 1: ScreenCaptureKit with display-relative crop
        do {
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
            
            let fullImage = try await captureViaScreenCaptureKit(displayID: matchingDisplayID, showsCursor: showsCursor)
            let displayBounds = CGDisplayBounds(matchingDisplayID)
            
            return try ImageProcessor.crop(
                cgImage: fullImage,
                displayLogicalBounds: displayBounds,
                selectionLogicalRect: globalRect
            )
        } catch {
            // Attempt Tier 2: System CLI with exact rect capture
            do {
                return try await captureViaSystemCLI(displayID: nil, rect: globalRect, showsCursor: showsCursor)
            } catch let fallbackError {
                if !Self.hasPermission {
                    throw ScreenCaptureError.permissionDenied
                }
                throw ScreenCaptureError.captureFailed("Rect capture failed: \(error.localizedDescription); Fallback error: \(fallbackError.localizedDescription)")
            }
        }
    }
    
    // MARK: - Tier 1: ScreenCaptureKit
    
    private func captureViaScreenCaptureKit(
        displayID: CGDirectDisplayID,
        showsCursor: Bool
    ) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find matching display or fall back to first available display
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplaysAvailable
        }
        
        // Exclude our own application from the capture filter
        let myPID = ProcessInfo.processInfo.processIdentifier
        let excludedApps = content.applications.filter { $0.processID == myPID }
        
        let filter = SCContentFilter(display: scDisplay, excludingApplications: excludedApps, exceptingWindows: [])
        
        let config = SCStreamConfiguration()
        let pixelWidth = CGDisplayPixelsWide(scDisplay.displayID)
        let pixelHeight = CGDisplayPixelsHigh(scDisplay.displayID)
        
        config.width = pixelWidth > 0 ? pixelWidth : scDisplay.width * 2
        config.height = pixelHeight > 0 ? pixelHeight : scDisplay.height * 2
        config.showsCursor = showsCursor
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
    
    // MARK: - Tier 2: Native System CLI Fallback
    
    private func captureViaSystemCLI(
        displayID: CGDirectDisplayID?,
        rect: CGRect?,
        showsCursor: Bool
    ) async throws -> CGImage {
        return try await Task.detached(priority: .high) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("natively_shot_\(UUID().uuidString).png")
            defer {
                try? FileManager.default.removeItem(at: tempFile)
            }
            
            var args: [String] = ["-x"] // silent: no camera sound
            if showsCursor {
                args.append("-C")
            }
            
            if let r = rect {
                let rx = Int(r.origin.x.rounded())
                let ry = Int(r.origin.y.rounded())
                let rw = max(1, Int(r.width.rounded()))
                let rh = max(1, Int(r.height.rounded()))
                args.append("-R")
                args.append("\(rx),\(ry),\(rw),\(rh)")
            } else if let did = displayID {
                // Determine 1-based display index for screencapture CLI
                var displayCount: UInt32 = 0
                CGGetActiveDisplayList(0, nil, &displayCount)
                if displayCount > 0 {
                    var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
                    CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
                    if let index = displayIDs.firstIndex(of: did) {
                        args.append("-D")
                        args.append("\(index + 1)")
                    }
                }
            }
            
            args.append(tempFile.path)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = args
            
            let pipe = Pipe()
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorStr = String(data: errorData, encoding: .utf8) ?? "code \(process.terminationStatus)"
                throw ScreenCaptureError.captureFailed("screencapture exited with \(errorStr)")
            }
            
            guard FileManager.default.fileExists(atPath: tempFile.path),
                  let source = CGImageSourceCreateWithURL(tempFile as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ScreenCaptureError.captureFailed("Unable to decode captured PNG into CGImage.")
            }
            
            return cgImage
        }.value
    }
}
