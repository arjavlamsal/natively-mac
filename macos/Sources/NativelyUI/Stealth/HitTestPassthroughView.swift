import AppKit
import Foundation

/// A high-performance NSView that supports transparent click-through
/// to windows underneath, eliminating the need for auxiliary child windows.
public final class HitTestPassthroughView: NSView {
    /// When true, all mouse events pass straight through to background apps.
    public var isPassthroughEnabled: Bool = false
    
    /// Optional closure providing bounding rects of currently interactive UI elements (e.g. pill, cards).
    /// Mouse events outside these rects pass through seamlessly to underlying windows.
    public var interactiveBoundsProvider: (() -> [NSRect])?

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // If global mouse passthrough is enabled, drop all clicks to the OS.
        if isPassthroughEnabled {
            return nil
        }
        
        // If interactive bounds are specified, test against them.
        if let provider = interactiveBoundsProvider {
            let activeRects = provider()
            let isInsideActiveElement = activeRects.contains { rect in
                rect.contains(point)
            }
            if !isInsideActiveElement {
                return nil // Click goes through transparent canvas!
            }
        }
        
        return super.hitTest(point)
    }
    
    /// Allows immediate single-click interactions without requiring prior window activation.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
