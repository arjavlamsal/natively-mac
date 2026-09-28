import SwiftUI
import NativelyCore

/// Fast popup settings adhering to macOS HIG with native toggles and keybindings.
public struct QuickSettingsPopoverView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    @AppStorage("natively_fast_response") private var isFastResponse: Bool = true
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Text("QUICK CONTROLS")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            // 1. Undetectability / Stealth Toggle
            Toggle(isOn: $isUndetectable) {
                HStack(spacing: 8) {
                    Image(systemName: isUndetectable ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isUndetectable ? NativelyTheme.emeraldGreen : .secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isUndetectable ? "Undetectable" : "Detectable")
                            .font(.system(size: 11.5, weight: .medium))
                        Text(isUndetectable ? "Invisible to screen share" : "Visible in captures")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .green))
            
            Divider()
                .opacity(0.4)
            
            // 2. Fast Response Mode
            Toggle(isOn: $isFastResponse) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.warningAmber)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fast Response")
                            .font(.system(size: 11.5, weight: .medium))
                        Text("Ultra-low latency streaming")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .yellow))
            
            Divider()
                .opacity(0.4)
            
            // 3. Rolling Transcript Display
            Toggle(isOn: $viewModel.showRollingTranscript) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.cyanBlue)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rolling Transcript")
                            .font(.system(size: 11.5, weight: .medium))
                        Text("Show live conversation stream")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
            
            Divider()
                .opacity(0.4)
            
            // 4. Direct Assist Toggle
            Toggle(isOn: $viewModel.isDirectAssist) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.purpleAccent)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Direct Assist")
                            .font(.system(size: 11.5, weight: .medium))
                        Text("Bypass turn planner routing")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .purple))
            
            Divider()
                .opacity(0.4)
            
            // 5. Shortcuts Cheat Sheet
            VStack(alignment: .leading, spacing: 5) {
                shortcutRow(key: "⌘B", label: "Show / Hide Overlay")
                shortcutRow(key: "⌘⇧X", label: "Crop Screen Region")
                shortcutRow(key: "⌘1", label: "What Should I Say?")
                shortcutRow(key: "⌘2", label: "Clarify Question")
                shortcutRow(key: "⌘3", label: "Recap Constraints")
            }
            .padding(.vertical, 2)
            
            Divider()
                .opacity(0.4)
            
            // 6. Open Full Settings Button
            Button(action: {
                viewModel.isQuickSettingsPresented = false
                viewModel.onOpenLauncher?()
            }) {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Open Preferences...")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 230)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func shortcutRow(key: String, label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            Spacer()
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}
