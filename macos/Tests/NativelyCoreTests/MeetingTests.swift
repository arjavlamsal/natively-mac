import Testing
import Foundation
@testable import NativelyCore

@Suite("NativelyCore Models Tests")
struct MeetingTests {
    @Test("Meeting and DetailedSummary JSON serialization roundtrip")
    func testMeetingSerialization() throws {
        let actionItem = ActionItem(id: "item-1", text: "Ship native macOS app", owner: "Team", deadline: "2026-10-01")
        let summary = DetailedSummary(
            overview: "Architecture transformation meeting",
            actionItems: ["Ship native macOS app"],
            actionItemsV3: [actionItem],
            keyPoints: ["Electron is bulky", "Swift 6 is blazing fast"],
            tldr: ["Transforming to native macOS app"]
        )

        let summaryData = try JSONEncoder().encode(summary)
        let summaryJson = String(data: summaryData, encoding: .utf8)

        let meeting = Meeting(
            id: "meeting-123",
            title: "Native Architecture Alignment",
            startTime: 1774742400000,
            durationMs: 3600000,
            summaryJson: summaryJson,
            source: "manual",
            isProcessed: true,
            summaryStatus: "completed"
        )

        #expect(meeting.id == "meeting-123")
        #expect(meeting.title == "Native Architecture Alignment")
        #expect(meeting.isProcessed == true)

        let parsed = meeting.parsedSummary
        #expect(parsed != nil)
        #expect(parsed?.overview == "Architecture transformation meeting")
        #expect(parsed?.actionItemsV3?.first?.text == "Ship native macOS app")
        #expect(parsed?.actionItemsV3?.first?.owner == "Team")
    }

    @Test("TranscriptTurn model initialization")
    func testTranscriptTurn() {
        let turn = TranscriptTurn(
            id: 1,
            meetingId: "meeting-123",
            speaker: "Interviewer",
            content: "What are the advantages of Swift over Electron?",
            timestampMs: 12000
        )

        #expect(turn.meetingId == "meeting-123")
        #expect(turn.speaker == "Interviewer")
        #expect(turn.content == "What are the advantages of Swift over Electron?")
        #expect(turn.timestampMs == 12000)
    }

    @Test("AppSettings default values")
    func testAppSettings() {
        let settings = AppSettings()
        #expect(settings.selectedSTTEngine == .whisperKit)
        #expect(settings.isStealthModeEnabled == true)
        #expect(settings.isAdaptiveDockEnabled == true)
        #expect(settings.selectedAIProvider == .anthropic)
    }

    @Test("CalendarEvent model initialization and formatting")
    func testCalendarEvent() {
        let now = Date()
        let event = CalendarEvent(
            id: "cal-1",
            title: "Q3 Engineering Sync",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            attendees: ["Alex", "Jordan"],
            location: "Zoom",
            meetingURL: URL(string: "https://zoom.us/j/123456789"),
            notes: "Discussion on Swift port"
        )

        #expect(event.id == "cal-1")
        #expect(event.title == "Q3 Engineering Sync")
        #expect(event.attendees.count == 2)
        #expect(event.isOngoing == true)
        #expect(event.meetingURL?.absoluteString == "https://zoom.us/j/123456789")
        #expect(event.formattedTimeLabel == "Happening Now")
    }

    @Test("CalendarEvent future date formatting")
    func testCalendarEventFuture() {
        let tomorrow = Date().addingTimeInterval(86400)
        let event = CalendarEvent(
            id: "cal-2",
            title: "Future Planning",
            startDate: tomorrow,
            endDate: tomorrow.addingTimeInterval(3600)
        )
        #expect(event.isOngoing == false)
        #expect(event.formattedTimeLabel.contains("Tomorrow at") || event.formattedTimeLabel.contains("at"))
    }
}
