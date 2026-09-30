import Foundation

/// Represents a calendar meeting or interview event retrieved from Apple EventKit or external calendar sync.
public struct CalendarEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let attendees: [String]
    public let location: String?
    public let meetingURL: URL?
    public let notes: String?
    
    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        attendees: [String] = [],
        location: String? = nil,
        meetingURL: URL? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.attendees = attendees
        self.location = location
        self.meetingURL = meetingURL
        self.notes = notes
    }
    
    /// Returns true if the event is currently in progress.
    public var isOngoing: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }
    
    /// Formatted time label (e.g. "Today at 2:00 PM", "Tomorrow at 10:00 AM", or "In progress").
    public var formattedTimeLabel: String {
        if isOngoing {
            return "Happening Now"
        }
        
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: startDate)
        
        if calendar.isDateInToday(startDate) {
            let diffMinutes = Int(startDate.timeIntervalSinceNow / 60)
            if diffMinutes > 0 && diffMinutes <= 60 {
                return "In \(diffMinutes)m (\(timeString))"
            }
            return "Today at \(timeString)"
        } else if calendar.isDateInTomorrow(startDate) {
            return "Tomorrow at \(timeString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE, MMM d"
            return "\(dayFormatter.string(from: startDate)) at \(timeString)"
        }
    }
}
