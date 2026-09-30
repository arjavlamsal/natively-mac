import SwiftUI
import NativelyCore

/// Hero card displaying upcoming calendar meetings from Apple Calendar / Google / Outlook
/// with 1-click meeting start and video conference links.
public struct UpcomingCalendarCardView: View {
    @State private var events: [CalendarEvent] = []
    @State private var isAuthorized: Bool = false
    @State private var isLoading: Bool = false
    
    public var onStartMeetingForEvent: ((CalendarEvent) -> Void)?
    
    public init(onStartMeetingForEvent: ((CalendarEvent) -> Void)? = nil) {
        self.onStartMeetingForEvent = onStartMeetingForEvent
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(NativelyTheme.skyAccent)
                        .font(.system(size: 12))
                    Text("UPCOMING MEETINGS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.skyAccent)
                }
                
                Spacer()
                
                if isAuthorized {
                    Button(action: refreshCalendar) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Calendar")
                }
            }
            
            if !isAuthorized {
                // Not Connected State
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect your calendar to view upcoming meetings and start recordings with one click.")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .lineSpacing(2)
                    
                    Button(action: requestCalendarAccess) {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Connect Mac Calendar")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(NativelyTheme.skyAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            } else if events.isEmpty {
                // Empty state
                VStack(alignment: .leading, spacing: 4) {
                    Text("No upcoming meetings scheduled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text("Your calendar is clear for the next 24 hours.")
                        .font(.system(size: 11.5))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
                .padding(.vertical, 6)
            } else {
                // Meeting list (up to 3)
                VStack(spacing: 8) {
                    ForEach(events.prefix(3)) { event in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(NativelyTheme.textPrimary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(event.formattedTimeLabel)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(event.isOngoing ? NativelyTheme.emeraldGreen : NativelyTheme.textSecondary)
                                    
                                    if !event.attendees.isEmpty {
                                        Text("•")
                                            .foregroundColor(NativelyTheme.textTertiary)
                                        Text("\(event.attendees.count) attendees")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(NativelyTheme.textTertiary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Join & Record Button
                            Button(action: {
                                onStartMeetingForEvent?(event)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "record.circle")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Join & Record")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4.5)
                                .background(event.isOngoing ? NativelyTheme.emeraldGreen : NativelyTheme.skyAccent)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.10), NativelyTheme.bgElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.purple.opacity(0.20), lineWidth: 0.5)
        )
        .onAppear {
            checkStatusAndLoad()
        }
    }
    
    private func checkStatusAndLoad() {
        isAuthorized = CalendarService.shared.isAuthorized()
        if isAuthorized {
            refreshCalendar()
        }
    }
    
    private func requestCalendarAccess() {
        Task {
            let granted = await CalendarService.shared.requestAccess()
            await MainActor.run {
                self.isAuthorized = granted
                if granted {
                    refreshCalendar()
                }
            }
        }
    }
    
    private func refreshCalendar() {
        guard isAuthorized else { return }
        isLoading = true
        Task {
            let fetched = await CalendarService.shared.fetchUpcomingEvents(hoursAhead: 24)
            await MainActor.run {
                self.events = fetched
                self.isLoading = false
            }
        }
    }
}
