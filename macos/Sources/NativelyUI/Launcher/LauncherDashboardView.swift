import SwiftUI
import NativelyCore

/// Main Launcher window dashboard adhering to macOS Human Interface Guidelines.
/// Uses a native NavigationSplitView with unified macOS toolbar, hardware stealth controls,
/// live session toggle, and deep meeting inspection.
public struct LauncherDashboardView: View {
    @StateObject public var viewModel: LauncherViewModel
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    
    public init(viewModel: LauncherViewModel = LauncherViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        NavigationSplitView {
            MeetingListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if let selected = viewModel.selectedMeeting {
                MeetingDetailView(viewModel: viewModel, meeting: selected)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Natively")
        .toolbar {
            // Leading: App Branding & Status
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NativelyTheme.purpleAccent)
                    Text("Natively")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("NATIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.purpleAccent)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(NativelyTheme.purpleAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            
            // Trailing: Controls & Actions
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    // Hardware Stealth Toggle
                    Button(action: {
                        isUndetectable.toggle()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: isUndetectable ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 11))
                            Text(isUndetectable ? "Stealth" : "Visible")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(isUndetectable ? .green : .secondary)
                    .help(isUndetectable ? "Hardware Stealth Active (Invisible on screen shares)" : "Stealth Disabled")
                    
                    // Start / Stop Meeting CTA
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.toggleMeetingSession()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.isMeetingActive ? Color.red : Color.green)
                                .frame(width: 7, height: 7)
                            Text(viewModel.isMeetingActive ? "Stop Meeting" : "Start Natively")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isMeetingActive ? .red : .accentColor)
                    
                    // Settings Button
                    Button(action: {
                        viewModel.isSettingsPresented = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12.5))
                    }
                    .buttonStyle(.bordered)
                    .help("Preferences (⌘,)")
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 76, height: 76)
                
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundColor(Color.accentColor.opacity(0.8))
            }
            
            VStack(spacing: 6) {
                Text("Ready for your next call")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Select a previous meeting to view notes and transcripts, or click 'Start Natively' to begin real-time assistance.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.startMeeting()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "record.circle.fill")
                        .font(.system(size: 12))
                    Text("Start New Session")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
            // Shortcuts Guide Card
            HStack(spacing: 18) {
                shortcutItem(keys: "⌘B", label: "Toggle Overlay")
                shortcutItem(keys: "⌘⇧X", label: "Screen Crop")
                shortcutItem(keys: "⌘⇧B", label: "Passthrough")
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func shortcutItem(keys: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
    }
}
