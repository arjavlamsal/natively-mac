import SwiftUI
import NativelyCore

/// Main Launcher window dashboard matching Natively's original high-polish desktop experience.
/// Replicates the original layout: TopSearchPill, My Natively hero header, Glowing CTA button,
/// Feature Spotlight cards, and full-bleed Meeting Details navigation.
public struct LauncherDashboardView: View {
    @StateObject public var viewModel: LauncherViewModel
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    
    @State private var isRefreshing: Bool = false
    @State private var isPulsing: Bool = false
    
    public init(viewModel: LauncherViewModel = LauncherViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        ZStack {
            NativelyTheme.bgPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. TOP HEADER (Static Bar with Search Pill & Actions)
                topHeaderBar
                
                Divider()
                    .background(NativelyTheme.borderSubtle)
                
                // 2. MAIN CONTENT: Switch between Launcher Dashboard and Full Meeting Details
                if let selected = viewModel.selectedMeeting {
                    MeetingDetailView(viewModel: viewModel, meeting: selected)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    dashboardMainContent
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsSheetView(viewModel: viewModel)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .onChange(of: isUndetectable) { _, newValue in
            OverlayWindowManager.shared.setStealthMode(newValue)
        }
    }
    
    // MARK: - 1. Top Header Bar
    
    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            // Left: Brand Logo
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(NativelyTheme.purpleAccent.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NativelyTheme.purpleAccent)
                }
                
                Text("Natively")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(NativelyTheme.textPrimary)
            }
            .padding(.leading, 18)
            
            Spacer()
            
            // Center: Spotlight-style TopSearchPill
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                TextField("Ask Natively or search meetings...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(NativelyTheme.textPrimary)
                    .frame(width: 260)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("⌘K")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(NativelyTheme.textTertiary)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(NativelyTheme.bgElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
            )
            
            Spacer()
            
            // Right: Profile, Modes & Settings Buttons
            HStack(spacing: 4) {
                Button(action: {
                    viewModel.settingsSelectedTab = "profile"
                    viewModel.isSettingsPresented = true
                }) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Profile Intelligence")
                
                Button(action: {
                    viewModel.settingsSelectedTab = "modes"
                    viewModel.isSettingsPresented = true
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Modes & Prompts")
                
                Button(action: {
                    viewModel.settingsSelectedTab = "general"
                    viewModel.isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13.5))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
            }
            .padding(.trailing, 18)
        }
        .frame(height: 48)
        .background(NativelyTheme.bgSecondary)
    }
    
    // MARK: - 2. Dashboard Main Content
    
    private var dashboardMainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // TOP HERO SECTION (Title + Controls + Glowing Hero CTA)
                heroControlsSection
                
                // HERO FEATURE CARDS
                heroCardsGrid
                
                // RECENT MEETINGS SECTION
                recentMeetingsSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
    }
    
    // MARK: - Hero Controls Section
    
    private var heroControlsSection: some View {
        HStack(alignment: .center) {
            // Left: Title + Controls
            HStack(spacing: 12) {
                Text("My Natively")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(NativelyTheme.textPrimary)
                
                // Refresh Button
                Button(action: {
                    isRefreshing = true
                    viewModel.loadMeetings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isRefreshing = false
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 0.6) : .default, value: isRefreshing)
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Refresh Meetings")
                
                // Undetectable Toggle Pill
                HStack(spacing: 6) {
                    Image(systemName: isUndetectable ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isUndetectable ? NativelyTheme.textSecondary : NativelyTheme.warningAmber)
                    
                    Text(isUndetectable ? "Undetectable" : "Detectable")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(NativelyTheme.textSecondary)
                    
                    Toggle("", isOn: $isUndetectable)
                        .toggleStyle(SwitchToggleStyle(tint: NativelyTheme.skyAccent))
                        .labelsHidden()
                        .scaleEffect(0.65)
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 3)
                .background(NativelyTheme.bgElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                )
                
                // What's New Pill
                HStack(spacing: 4) {
                    Text("What's New in v2.7")
                        .font(.system(size: 11.5, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundColor(NativelyTheme.emeraldGreen)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(NativelyTheme.emeraldGreen.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(NativelyTheme.emeraldGreen.opacity(0.25), lineWidth: 0.5)
                )
            }
            
            Spacer()
            
            // Right: GLOWING HERO CTA BUTTON (Sky Blue Idle / Emerald Active)
            Button(action: {
                withAnimation(NativelyTheme.smoothSpring) {
                    viewModel.toggleMeetingSession()
                }
            }) {
                HStack(spacing: 9) {
                    if viewModel.isMeetingActive {
                        // Pinging active dot
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 14, height: 14)
                                .scaleEffect(isPulsing ? 1.5 : 1.0)
                                .opacity(isPulsing ? 0 : 0.8)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text("Meeting ongoing")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "sparkle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Start Natively")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    viewModel.isMeetingActive ? NativelyTheme.ctaActiveGradient : NativelyTheme.ctaIdleGradient
                )
                .clipShape(Capsule())
                .overlay(
                    // Top highlight specular sheen
                    VStack {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: 18)
                            .padding(.horizontal, 6)
                            .padding(.top, 1)
                        Spacer()
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(
                    color: viewModel.isMeetingActive ?
                        Color(red: 0.10, green: 0.85, blue: 0.50).opacity(0.45) :
                        Color(red: 0.05, green: 0.65, blue: 0.95).opacity(0.45),
                    radius: 14, x: 0, y: 4
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Hero Cards Grid
    
    private var heroCardsGrid: some View {
        HStack(spacing: 16) {
            // Card 1: Feature Spotlight
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(NativelyTheme.purpleAccent)
                        .font(.system(size: 12))
                    Text("REAL-TIME AI COPILOT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.purpleAccent)
                }
                
                Text("Zero-latency stealth intelligence during meetings & interviews")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(NativelyTheme.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    featureTag(label: "Hardware Stealth", icon: "shield.fill")
                    featureTag(label: "140ms TTFT", icon: "bolt.fill")
                    featureTag(label: "Vision OCR", icon: "crop")
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [NativelyTheme.bgCard, NativelyTheme.bgElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
            )
            
            // Card 2: Upcoming Calendar Meetings & Join Action
            UpcomingCalendarCardView { event in
                if let url = event.meetingURL {
                    NSWorkspace.shared.open(url)
                }
                viewModel.startMeeting(title: event.title)
            }
        }
    }
    
    private func featureTag(label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5))
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundColor(NativelyTheme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
    
    // MARK: - Recent Meetings Section
    
    private var recentMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Meetings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(NativelyTheme.textPrimary)
            
            if viewModel.groupedMeetings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 32))
                        .foregroundColor(NativelyTheme.textTertiary)
                    Text("No meetings recorded yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(NativelyTheme.textSecondary)
                    Text("Click 'Start Natively' to begin recording and getting instant AI solutions.")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(NativelyTheme.bgCard.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
                )
            } else {
                ForEach(viewModel.groupedMeetings) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(NativelyTheme.textTertiary)
                            .padding(.leading, 4)
                        
                        ForEach(group.meetings) { meeting in
                            meetingCard(meeting)
                        }
                    }
                }
            }
        }
    }
    
    private func meetingCard(_ meeting: Meeting) -> some View {
        Button(action: {
            withAnimation(NativelyTheme.smoothSpring) {
                viewModel.selectMeeting(meeting)
            }
        }) {
            HStack(alignment: .center, spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(NativelyTheme.skyAccent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(meeting.title ?? "Untitled Meeting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(NativelyTheme.textPrimary)
                            .lineLimit(1)
                        
                        if let durationMs = meeting.durationMs, durationMs > 0 {
                            Text(formatDuration(durationMs))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(NativelyTheme.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Text(formatDate(meeting.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    
                    if let summary = meeting.summaryJson, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12))
                            .foregroundColor(NativelyTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(NativelyTheme.textTertiary)
                    .padding(.trailing, 4)
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ ms: Int64) -> String {
        let totalSecs = ms / 1000
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatDate(_ isoString: String?) -> String {
        guard let isoString, let date = ISO8601DateFormatter().date(from: isoString) else {
            return "Just now"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
