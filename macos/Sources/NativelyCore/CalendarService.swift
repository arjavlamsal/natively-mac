import Foundation
import EventKit

/// Native macOS Calendar Service using Apple EventKit.
/// Seamlessly reads all calendars configured on macOS (Google Calendar, Apple iCloud, Microsoft Exchange, Outlook)
/// without requiring third-party OAuth loopback servers.
public final class CalendarService: @unchecked Sendable {
    public static let shared = CalendarService()
    
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    /// Checks current calendar authorization status.
    public func isAuthorized() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }
    
    /// Requests native calendar access from macOS System Settings.
    public func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Fetches upcoming calendar events for the specified number of hours ahead.
    public func fetchUpcomingEvents(hoursAhead: Int = 24) async -> [CalendarEvent] {
        guard isAuthorized() else { return [] }
        
        let now = Date()
        // Include events that started up to 30 minutes ago in case a meeting just started
        let startDate = now.addingTimeInterval(-1800)
        let endDate = now.addingTimeInterval(TimeInterval(hoursAhead * 3600))
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        // Sort by start date ascending
        let sorted = ekEvents.sorted { $0.startDate < $1.startDate }
        
        return sorted.compactMap { ekEvent -> CalendarEvent? in
            guard let title = ekEvent.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            
            let attendees: [String] = ekEvent.attendees?.compactMap { attendee in
                if let name = attendee.name, !name.isEmpty {
                    return name
                }
                if let spec = (attendee.url as NSURL).resourceSpecifier, !spec.isEmpty {
                    return spec
                }
                return attendee.url.absoluteString
            } ?? []
            
            let meetingURL = extractMeetingURL(from: ekEvent)
            
            return CalendarEvent(
                id: ekEvent.eventIdentifier ?? UUID().uuidString,
                title: title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                attendees: attendees,
                location: ekEvent.location,
                meetingURL: meetingURL,
                notes: ekEvent.notes
            )
        }
    }
    
    /// Discovers video meeting links (Zoom, Google Meet, Microsoft Teams, Webex) from an EKEvent.
    private func extractMeetingURL(from event: EKEvent) -> URL? {
        // 1. Direct URL property
        if let url = event.url, isVideoConferenceURL(url) {
            return url
        }
        
        // 2. Scan location string
        if let location = event.location, let url = extractURL(from: location), isVideoConferenceURL(url) {
            return url
        }
        
        // 3. Scan notes / description
        if let notes = event.notes, let url = extractURL(from: notes), isVideoConferenceURL(url) {
            return url
        }
        
        return event.url
    }
    
    private func isVideoConferenceURL(_ url: URL) -> Bool {
        let str = url.absoluteString.lowercased()
        return str.contains("zoom.us/") ||
               str.contains("meet.google.com/") ||
               str.contains("teams.microsoft.com/") ||
               str.contains("webex.com/") ||
               str.contains("chime.aws/") ||
               str.contains("around.co/")
    }
    
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
        return matches?.first?.url
    }
}
