import AppKit
import SwiftUI
import NativelyCore
import NativelyDatabase
import NativelyVision
import NativelyAI

/// Orchestrates the lifecycle, positioning, and stealth configuration of the overlay panel.
@MainActor
public final class OverlayWindowManager: ObservableObject {
    public static let shared = OverlayWindowManager()
    
    public let viewModel: OverlayViewModel
    public private(set) var panel: StealthPanel?
    public var screenVisionCoordinator: ScreenVisionCoordinator?
    
    private var initialDragOrigin: NSPoint?
    
    public init(database: AppDatabase = .shared) {
        self.viewModel = OverlayViewModel(database: database)
    }
    
    /// Initializes and presents the stealth overlay panel.
    public func showOverlay() {
        if let panel {
            panel.orderFront(nil)
            return
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialWidth: CGFloat = 496
        let initialHeight: CGFloat = 520
        let initialX = screenRect.midX - (initialWidth / 2)
        let initialY = screenRect.maxY - initialHeight - 16
        
        let contentRect = NSRect(x: initialX, y: initialY, width: initialWidth, height: initialHeight)
        let stealthPanel = StealthPanel(contentRect: contentRect)
        
        // Wrap SwiftUI content in HitTestPassthroughView
        let passthroughContainer = HitTestPassthroughView(frame: NSRect(origin: .zero, size: contentRect.size))
        passthroughContainer.autoresizingMask = [.width, .height]
        
        let contentView = OverlayContentView(
            viewModel: viewModel,
            onCropTrigger: { [weak self] in
                self?.handleCropTrigger()
            },
            onWindowDrag: { [weak self] translation in
                self?.handleWindowDrag(translation)
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = passthroughContainer.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        passthroughContainer.addSubview(hostingView)
        stealthPanel.contentView = passthroughContainer
        
        self.panel = stealthPanel
        setupHotkeys()
        
        stealthPanel.orderFront(nil)
    }
    
    /// Hides the overlay panel.
    public func hideOverlay() {
        panel?.orderOut(nil)
    }
    
    /// Toggles overlay visibility.
    public func toggleVisibility() {
        guard let panel else {
            showOverlay()
            return
        }
        if panel.isVisible {
            hideOverlay()
        } else {
            panel.orderFront(nil)
        }
    }
    
    /// Toggles mouse passthrough / click-through mode.
    public func toggleMousePassthrough() {
        guard let panel else { return }
        let newState = !panel.ignoresMouseEvents
        panel.setMousePassthrough(newState)
        viewModel.isPassthrough = newState
    }
    
    /// Focuses the prompt input without activating other apps.
    public func focusPromptInput() {
        guard let panel else { return }
        if !panel.isVisible {
            panel.orderFront(nil)
        }
        panel.makeKey()
        viewModel.isExpanded = true
        viewModel.isFocusingPrompt = true
    }
    
    /// Triggers the interactive cropper and sends OCR output to the active context.
    public func handleCropTrigger() {
        Task { [weak self] in
            guard let self, let vision = self.screenVisionCoordinator else {
                // If vision coordinator not injected, set mock OCR for preview/testing
                self?.viewModel.attachScreenContext(
                    ocrText: "Example OCR: Given an array of integers nums, return indices of the two numbers such that they add up to target.",
                    imageBase64: nil
                )
                return
            }
            
            do {
                if let cropResult = try await vision.captureAndAnalyze(region: .interactiveCropper) {
                    self.viewModel.attachScreenContext(
                        ocrText: cropResult.ocrResult.fullText,
                        imageBase64: cropResult.base64DataUrl
                    )
                }
            } catch {
                // User cancelled or capture failed
            }
        }
    }
    
    private func setupHotkeys() {
        let hotkeys = HotkeyManager.shared
        hotkeys.registerDefaultHotkeys()
        
        hotkeys.onAction(.toggleVisibility) { [weak self] in
            self?.toggleVisibility()
        }
        hotkeys.onAction(.toggleMousePassthrough) { [weak self] in
            self?.toggleMousePassthrough()
        }
        hotkeys.onAction(.toggleStealthFocus) { [weak self] in
            self?.focusPromptInput()
        }
        hotkeys.onAction(.triggerCrop) { [weak self] in
            self?.handleCropTrigger()
        }
        hotkeys.onAction(.captureAndAsk) { [weak self] in
            self?.handleCropTrigger()
            self?.viewModel.triggerQuickAction(presetNumber: 1)
        }
        hotkeys.onAction(.processScreenshots) { [weak self] in
            self?.viewModel.triggerQuickAction(presetNumber: 1)
        }
        
        // Quick Action Presets
        hotkeys.onAction(.quickAction1) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 1) }
        hotkeys.onAction(.quickAction2) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 2) }
        hotkeys.onAction(.quickAction3) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 3) }
        hotkeys.onAction(.quickAction4) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 4) }
        hotkeys.onAction(.quickAction5) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 5) }
        hotkeys.onAction(.quickAction6) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 6) }
        hotkeys.onAction(.quickAction7) { [weak self] in self?.viewModel.triggerQuickAction(presetNumber: 7) }
        
        // Micro-nudges
        hotkeys.onAction(.nudgeUp) { [weak self] in self?.panel?.nudge(dx: 0, dy: 10) }
        hotkeys.onAction(.nudgeDown) { [weak self] in self?.panel?.nudge(dx: 0, dy: -10) }
        hotkeys.onAction(.nudgeLeft) { [weak self] in self?.panel?.nudge(dx: -10, dy: 0) }
        hotkeys.onAction(.nudgeRight) { [weak self] in self?.panel?.nudge(dx: 10, dy: 0) }
    }
    
    private func handleWindowDrag(_ translation: CGSize) {
        guard let panel else { return }
        var frame = panel.frame
        frame.origin.x += translation.width
        frame.origin.y -= translation.height // In Cocoa, Y coordinates increase upwards
        panel.setFrameOrigin(frame.origin)
    }
}
