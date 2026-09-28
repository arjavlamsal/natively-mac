import AppKit
import SwiftUI
import NativelyUI

/// Application Delegate managing top-level macOS system lifecycle events.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let coordinator = AppCoordinator.shared
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Start all native background services, menu bar icon, and hotkey listeners
        coordinator.start()
        
        // Show launcher dashboard on first cold launch
        coordinator.launcherWindowManager.showLauncher()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            coordinator.launcherWindowManager.showLauncher()
        }
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        coordinator.shutdown()
    }
}
