import SwiftUI
import NativelyCore

/// Main Launcher window dashboard matching Natively's modern macOS desktop experience.
/// Features a centralized Top Search Pill, Undetectable Ghost mode toggle,
/// Start/Stop session hero action, split-view meeting history, and deep inspection.
public struct LauncherDashboardView: View {
    @StateObject public var viewModel: LauncherViewModel
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    
    public init(viewModel: LauncherViewModel = LauncherViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main Top Toolbar
            HStack(spacing: 12) {
                // 1. BRAND LOGO
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Natively")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("NATIVE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.purple.opacity(0.18))
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // 2. CENTRAL TOP SEARCH PILL
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.45))
                    TextField("Ask Natively or search meetings...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 240)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                Spacer()
                
                // 3. GHOST MODE / UNDETECTABLE TOGGLE
                Button(action: {
                    isUndetectable.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: isUndetectable ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(isUndetectable ? Color.green : Color.white.opacity(0.5))
                        Text(isUndetectable ? "Undetectable" : "Detectable")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isUndetectable ? Color.green : Color.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isUndetectable ? Color.green.opacity(0.12) : Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isUndetectable ? Color.green.opacity(0.25) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(isUndetectable ? "Invisible on screen shares (Zoom, Teams, Meet)" : "Visible in captures")
                
                // 4. "START NATIVELY" MEETING TOGGLE HERO CTA
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
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5.5)
                    .background(viewModel.isMeetingActive ? Color.red.opacity(0.25) : Color.green.opacity(0.25))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.isMeetingActive ? Color.red.opacity(0.6) : Color.green.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // 5. SETTINGS BUTTON
                Button(action: {
                    viewModel.isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(5.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open Preferences")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.07, green: 0.08, blue: 0.11))
            
            Divider().background(Color.white.opacity(0.12))
            
            // Split Content (Sidebar + Detail)
            HSplitView {
                MeetingListView(viewModel: viewModel)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                
                if let selected = viewModel.selectedMeeting {
                    MeetingDetailView(viewModel: viewModel, meeting: selected)
                        .frame(minWidth: 450)
                } else {
                    emptyStateView
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 36))
                .foregroundColor(Color.white.opacity(0.2))
            Text("Ready for your next call")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))
            Text("Select a previous meeting to view notes and transcripts, or click 'Start Natively' above.")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            
            Button(action: {
                viewModel.startMeeting()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Start Meeting")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.purple.opacity(0.4))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
    }
}
