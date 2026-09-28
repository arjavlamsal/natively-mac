import Foundation
import CoreGraphics

/// Defines the target region for a screen capture.
public enum ScreenRegion: Sendable, Equatable {
    /// Captures the entire primary/main display.
    case mainDisplay
    
    /// Captures a specific display by its CoreGraphics display ID.
    case display(CGDirectDisplayID)
    
    /// Captures an explicit rectangle in global screen coordinates.
    case customRect(CGRect)
    
    /// Triggers the interactive cropper window allowing the user to drag a selection.
    case interactiveCropper
}

/// Represents the geometry and pixel metrics of a captured screen area.
public struct CaptureGeometry: Sendable, Equatable {
    /// The selection rectangle in logical points (screen coordinates).
    public let bounds: CGRect
    
    /// The backing pixel scale factor (1.0 for standard, 2.0 for Retina, 3.0 for extreme HiDPI).
    public let scaleFactor: CGFloat
    
    /// The size of the resulting raster image in physical device pixels.
    public var pixelSize: CGSize {
        CGSize(
            width: bounds.width * scaleFactor,
            height: bounds.height * scaleFactor
        )
    }
    
    public init(bounds: CGRect, scaleFactor: CGFloat = 2.0) {
        self.bounds = bounds
        self.scaleFactor = max(1.0, scaleFactor)
    }
}
