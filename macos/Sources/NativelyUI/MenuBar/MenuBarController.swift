import AppKit
import SwiftUI
import NativelyCore
import NativelyDatabase

/// Controls the macOS system menu bar icon, status indicator, and context menu.
@MainActor
public final class MenuBarController: NSObject, ObservableObject {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var isMeetingActive: Bool = false
    private var meetingTitle: String = "Meeting"
    
    public var onToggleOverlay: (@MainActor () -> Void)?
    public var onTriggerCrop: (@MainActor () -> Void)?
    public var onOpenDashboard: (@MainActor () -> Void)?
    public var onToggleMeeting: (@MainActor () -> Void)?
    public var onSelectMode: (@MainActor (Mode) -> Void)?
    public var onOpenSettings: (@MainActor () -> Void)?
    
    private var availableModes: [Mode] = []
    private var activeModeId: String = ""
    
    public override init() {
        super.init()
    }
    
    /// Initializes and attaches the status item to the system menu bar.
    public func setupMenuBar() {
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: "Natively") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⚡︎"
            }
            button.toolTip = "Natively (Stealth AI Copilot)"
        }
        
        self.statusItem = item
        rebuildMenu()
    }
    
    /// Updates available modes and the currently active mode.
    public func updateModes(_ modes: [Mode], activeId: String) {
        self.availableModes = modes
        self.activeModeId = activeId
        rebuildMenu()
    }
    
    /// Updates the meeting active state in the menu bar.
    public func setMeetingState(isActive: Bool, title: String = "Meeting") {
        self.isMeetingActive = isActive
        self.meetingTitle = title
        
        if let button = statusItem?.button {
            let symbolName = isActive ? "record.circle.fill" : "waveform.badge.magnifyingglass"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Natively") {
                image.isTemplate = true
                button.image = image
            }
        }
        rebuildMenu()
    }
    
    /// Reconstructs the menu dynamically.
    public func rebuildMenu() {
        guard let statusItem else { return }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // App header
        let headerItem = NSMenuItem(title: "Natively 2.0 (Native Sequoia)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // Window & overlay controls
        let toggleOverlayItem = NSMenuItem(title: "Toggle Stealth Overlay", action: #selector(handleToggleOverlay), keyEquivalent: "b")
        toggleOverlayItem.keyEquivalentModifierMask = [.command]
        toggleOverlayItem.target = self
        menu.addItem(toggleOverlayItem)
        
        let cropItem = NSMenuItem(title: "Interactive Screen Crop", action: #selector(handleTriggerCrop), keyEquivalent: "X")
        cropItem.keyEquivalentModifierMask = [.command, .shift]
        cropItem.target = self
        menu.addItem(cropItem)
        
        let dashboardItem = NSMenuItem(title: "Open Launcher Dashboard", action: #selector(handleOpenDashboard), keyEquivalent: "o")
        dashboardItem.keyEquivalentModifierMask = [.command]
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Mode Submenu
        let modesMenuItem = NSMenuItem(title: "AI Mode", action: nil, keyEquivalent: "")
        let modesSubmenu = NSMenu()
        for mode in availableModes {
            let item = NSMenuItem(title: mode.name, action: #selector(handleModeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            if mode.id == activeModeId {
                item.state = .on
            }
            modesSubmenu.addItem(item)
        }
        modesMenuItem.submenu = modesSubmenu
        menu.addItem(modesMenuItem)
        
        // Meeting Toggle
        let meetingText = isMeetingActive ? "Stop Meeting (\(meetingTitle))" : "Start New Meeting"
        let meetingItem = NSMenuItem(title: meetingText, action: #selector(handleToggleMeeting), keyEquivalent: "")
        meetingItem.target = self
        menu.addItem(meetingItem)
        
        // Companion Server status
        let companionItem = NSMenuItem(title: "Companion Server: Port 4123 (Active)", action: nil, keyEquivalent: "")
        companionItem.isEnabled = false
        menu.addItem(companionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Natively", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Action Selectors
    
    @objc private func handleToggleOverlay() {
        onToggleOverlay?()
    }
    
    @objc private func handleTriggerCrop() {
        onTriggerCrop?()
    }
    
    @objc private func handleOpenDashboard() {
        onOpenDashboard?()
    }
    
    @objc private func handleToggleMeeting() {
        onToggleMeeting?()
    }
    
    @objc private func handleModeSelected(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? Mode {
            onSelectMode?(mode)
        }
    }
    
    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }
    
    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
