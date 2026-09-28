import AppKit
import SwiftUI
import NativelyDatabase
import NativelyCompanion

/// Window manager for the standard native macOS Launcher dashboard window.
@MainActor
public final class LauncherWindowManager: ObservableObject {
    public static let shared = LauncherWindowManager()
    
    public private(set) var window: NSWindow?
    public let viewModel: LauncherViewModel
    
    public init(database: AppDatabase = .shared) {
        self.viewModel = LauncherViewModel(database: database)
    }
    
    /// Presents the launcher window, creating it if needed.
    public func showLauncher() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 860
        let height: CGFloat = 580
        let originX = screenRect.midX - (width / 2)
        let originY = screenRect.midY - (height / 2)
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let newWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Natively"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.minSize = NSSize(width: 750, height: 480)
        newWindow.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: LauncherDashboardView(viewModel: viewModel))
        newWindow.contentView = hostingView
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Hides the launcher window.
    public func hideLauncher() {
        window?.orderOut(nil)
    }
    
    /// Toggles the launcher window visibility.
    public func toggleLauncher() {
        if window?.isVisible == true {
            hideLauncher()
        } else {
            showLauncher()
        }
    }
}
