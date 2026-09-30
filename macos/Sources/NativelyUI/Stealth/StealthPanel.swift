import AppKit
import Foundation

/// A non-activating floating NSPanel with hardware-level screen-share stealth (`sharingType = .none`).
/// Completely invisible to Zoom, Microsoft Teams, Google Meet, Discord, and ScreenCaptureKit.
@MainActor
public final class StealthPanel: NSPanel {
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Hardware-level stealth: window is omitted from all window server screen captures
        self.sharingType = .none
        
        // Float above standard windows and auxiliary fullscreen spaces
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // Transparency and composition
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false
    }
    
    /// Allows the panel to receive keyboard focus when the user triggers stealth typing,
    /// without taking over the active application in the macOS Dock or Menu Bar.
    public override var canBecomeKey: Bool {
        return true
    }
    
    /// Never steals the main window status from the user's active IDE, terminal, or browser.
    public override var canBecomeMain: Bool {
        return false
    }
    
    /// Sets hardware screen-share stealth (sharingType = .none or .readOnly)
    public func setStealthMode(_ enabled: Bool) {
        self.sharingType = enabled ? .none : .readOnly
    }
    
    /// Nudge the panel by delta points (used by global stealth hotkeys Cmd+Shift+Arrows)
    public func nudge(dx: CGFloat, dy: CGFloat) {
        var origin = frame.origin
        origin.x += dx
        origin.y += dy
        setFrameOrigin(origin)
    }
    
    /// Toggle click-through mode
    public func setMousePassthrough(_ passthrough: Bool) {
        self.ignoresMouseEvents = passthrough
        if let passthroughView = self.contentView as? HitTestPassthroughView {
            passthroughView.isPassthroughEnabled = passthrough
        }
    }
}

// MARK: - Universal Window Stealth Policy Extension

extension NSWindow {
    /// Applies hardware screen-share stealth (`sharingType = .none`) to this window.
    /// Completely invisible to ScreenCaptureKit, Zoom, Microsoft Teams, Google Meet, and OBS.
    @MainActor
    public func applyStealthPolicy(_ enabled: Bool? = nil) {
        let isStealth = enabled ?? (UserDefaults.standard.object(forKey: "natively_undetectable") as? Bool ?? true)
        self.sharingType = isStealth ? .none : .readOnly
    }
}

// MARK: - SwiftUI Stealth Enforcement View Modifier

import SwiftUI

/// SwiftUI ViewModifier that attaches an NSViewRepresentable hook to enforce stealth `sharingType = .none`
/// on any hosting NSWindow or sheet.
public struct EnforceStealthWindowModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .background(StealthWindowAccessor())
    }
}

private struct StealthWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.applyStealthPolicy()
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.applyStealthPolicy()
        }
    }
}

extension View {
    /// Enforces hardware screen-share stealth (`sharingType = .none`) on the enclosing window.
    public func enforceStealthMode() -> some View {
        self.modifier(EnforceStealthWindowModifier())
    }
}
