import Foundation
import AppKit
import CoreGraphics

/// Stealth NSPanel that overlays all connected displays for pixel-precision cropping.
public final class CropperPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        // Excludes cropper window completely from ScreenCaptureKit, Zoom, Meet, Teams
        self.sharingType = .none
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}

/// Custom NSView providing dimmed overlay, animated selection bounds, HUD readouts, and crosshairs.
public final class CropperOverlayView: NSView {
    
    public var onSelectionConfirmed: (@MainActor @Sendable (CGRect) -> Void)?
    public var onCancelled: (@MainActor @Sendable () -> Void)?
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var cursorPoint: CGPoint?
    private var trackingArea: NSTrackingArea?
    
    private let minSelectionSize: CGFloat = 8.0
    
    public override var isFlipped: Bool {
        // Use Cocoa bottom-left coordinate convention by default
        false
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        cursorPoint = loc
        needsDisplay = true
    }
    
    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        startPoint = loc
        currentPoint = loc
        needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        currentPoint = loc
        cursorPoint = loc
        needsDisplay = true
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard let sp = startPoint, let cp = currentPoint else {
            resetSelection()
            return
        }
        
        let rect = currentSelectionRect(from: sp, to: cp)
        if rect.width >= minSelectionSize && rect.height >= minSelectionSize {
            // Convert view coordinates to window/screen coordinates
            let windowRect = convert(rect, to: nil)
            let screenRect = window?.convertToScreen(windowRect) ?? windowRect
            onSelectionConfirmed?(screenRect)
        } else {
            resetSelection()
        }
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        // Esc key (53): Cancel
        if event.keyCode == 53 {
            onCancelled?()
            return
        }
        // Spacebar (49): Select full active display immediately
        if event.keyCode == 49 {
            let activeScreen = NSScreen.main?.frame ?? (NSScreen.screens.first?.frame ?? bounds)
            onSelectionConfirmed?(activeScreen)
            return
        }
        // Enter / Return (36)
        if event.keyCode == 36 {
            if let sp = startPoint, let cp = currentPoint {
                let rect = currentSelectionRect(from: sp, to: cp)
                if rect.width >= minSelectionSize && rect.height >= minSelectionSize {
                    let windowRect = convert(rect, to: nil)
                    let screenRect = window?.convertToScreen(windowRect) ?? windowRect
                    onSelectionConfirmed?(screenRect)
                    return
                }
            }
            // If no drag selection, Return confirms active screen
            let activeScreen = NSScreen.main?.frame ?? (NSScreen.screens.first?.frame ?? bounds)
            onSelectionConfirmed?(activeScreen)
            return
        }
        super.keyDown(with: event)
    }
    
    private func resetSelection() {
        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }
    
    private func currentSelectionRect(from p1: CGPoint, to p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let w = abs(p1.x - p2.x)
        let h = abs(p1.y - p2.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw global semi-transparent dimming veil
        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.fill(bounds)
        ctx.restoreGState()
        
        // 2. Draw active selection rectangle if dragging
        if let sp = startPoint, let cp = currentPoint {
            let selRect = currentSelectionRect(from: sp, to: cp)
            
            // Clear inside of selection so underlying screen content is crisp
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fill(selRect)
            ctx.restoreGState()
            
            // Draw dual-tone border (outer black shadow + inner crisp white stroke)
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.stroke(selRect)
            ctx.setLineWidth(0.5)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.5).cgColor)
            ctx.stroke(selRect.insetBy(dx: -1, dy: -1))
            ctx.restoreGState()
            
            // Draw dimension and instruction HUD pill
            drawHUD(for: selRect, in: ctx)
        } else if let cur = cursorPoint {
            // Draw subtle guide crosshairs when hovering
            drawCrosshairs(at: cur, in: ctx)
        }
    }
    
    private func drawCrosshairs(at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1.0)
        
        // Horizontal line
        ctx.move(to: CGPoint(x: 0, y: point.y))
        ctx.addLine(to: CGPoint(x: bounds.width, y: point.y))
        
        // Vertical line
        ctx.move(to: CGPoint(x: point.x, y: 0))
        ctx.addLine(to: CGPoint(x: point.x, y: bounds.height))
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    private func drawHUD(for rect: CGRect, in ctx: CGContext) {
        let text = "\(Int(rect.width)) × \(Int(rect.height)) pt  •  Esc to cancel"
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        let paddingX: CGFloat = 12.0
        let paddingY: CGFloat = 6.0
        let pillWidth = textSize.width + (paddingX * 2)
        let pillHeight = textSize.height + (paddingY * 2)
        
        // Position HUD centered above selection, or below if too close to top
        var pillY = rect.maxY + 10
        if pillY + pillHeight > bounds.maxY {
            pillY = max(10, rect.minY - pillHeight - 10)
        }
        let pillX = max(10, min(bounds.maxX - pillWidth - 10, rect.midX - (pillWidth / 2)))
        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        
        // Draw rounded HUD pill
        let path = NSBezierPath(roundedRect: pillRect, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.75).setFill()
        path.fill()
        
        NSColor.white.withAlphaComponent(0.2).setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        // Render text
        let textOrigin = CGPoint(x: pillX + paddingX, y: pillY + paddingY)
        attrString.draw(at: textOrigin)
    }
}

/// Controller managing the presentation and lifecycle of the interactive cropper.
@MainActor
public final class InteractiveCropper: NSObject {
    private var panel: CropperPanel?
    private var overlayView: CropperOverlayView?
    private var continuation: CheckedContinuation<CGRect?, Never>?
    
    public override init() {
        super.init()
    }
    
    /// Presents the full-desktop cropper overlay and asynchronously returns the selected screen rect.
    /// Returns `nil` if cancelled by the user.
    public func promptForCropSelection() async -> CGRect? {
        let unionBounds = calculateCombinedScreenBounds()
        
        let panel = CropperPanel(contentRect: unionBounds)
        let overlay = CropperOverlayView(frame: NSRect(origin: .zero, size: unionBounds.size))
        panel.contentView = overlay
        
        self.panel = panel
        self.overlayView = overlay
        
        return await withCheckedContinuation { cont in
            self.continuation = cont
            
            overlay.onSelectionConfirmed = { [weak self] selectedRect in
                self?.finish(with: selectedRect)
            }
            
            overlay.onCancelled = { [weak self] in
                self?.finish(with: nil)
            }
            
            panel.setFrame(unionBounds, display: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(overlay)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func finish(with rect: CGRect?) {
        guard let cont = continuation else { return }
        continuation = nil
        dismiss()
        cont.resume(returning: rect)
    }
    
    public func dismiss() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
        overlayView = nil
    }
    
    private func calculateCombinedScreenBounds() -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for screen in screens {
            let f = screen.frame
            minX = min(minX, f.minX)
            minY = min(minY, f.minY)
            maxX = max(maxX, f.maxX)
            maxY = max(maxY, f.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
