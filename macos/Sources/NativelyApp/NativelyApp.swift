import SwiftUI
import NativelyUI

/// Main executable entry point for Natively macOS.
@main
struct NativelyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsSheetView(viewModel: appDelegate.coordinator.launcherWindowManager.viewModel)
        }
    }
}
