import SwiftUI
import NativelyCore

/// Main Launcher window dashboard featuring split-view meeting history and global controls.
public struct LauncherDashboardView: View {
    @StateObject public var viewModel: LauncherViewModel
    
    public init(viewModel: LauncherViewModel = LauncherViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main App Top Toolbar
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Natively")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // "Start Natively" Meeting Toggle Pill
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleMeetingSession()
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isMeetingActive ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isMeetingActive ? "Stop Meeting" : "Start Natively")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(viewModel.isMeetingActive ? Color.red.opacity(0.25) : Color.green.opacity(0.25))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(viewModel.isMeetingActive ? Color.red.opacity(0.6) : Color.green.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Settings Button
                Button(action: {
                    viewModel.isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.07, green: 0.08, blue: 0.11))
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Split Content (Sidebar + Detail)
            HSplitView {
                MeetingListView(viewModel: viewModel)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
                
                if let selected = viewModel.selectedMeeting {
                    MeetingDetailView(viewModel: viewModel, meeting: selected)
                        .frame(minWidth: 450)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 32))
                            .foregroundColor(Color.white.opacity(0.2))
                        Text("No Meeting Selected")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                        Text("Select a previous meeting to view notes or press 'Start Natively' above.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.16))
                }
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
    }
}
