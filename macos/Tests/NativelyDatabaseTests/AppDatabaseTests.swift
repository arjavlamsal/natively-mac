import Testing
import Foundation
@testable import NativelyCore
@testable import NativelyDatabase

@Suite("AppDatabase Tests")
struct AppDatabaseTests {
    @Test("In-memory database initialization, migration, and meeting CRUD")
    func testMeetingCRUD() throws {
        let db = try AppDatabase.makeInMemory()

        let meeting = Meeting(
            id: "m-001",
            title: "First Native Meeting",
            startTime: 1774742400000,
            durationMs: 1800000,
            summaryJson: "{\"overview\":\"Testing native database persistence\"}",
            source: "manual",
            isProcessed: true,
            summaryStatus: "completed"
        )

        // Save
        try db.saveMeeting(meeting)

        // Fetch One
        let fetched = try db.fetchMeeting(id: "m-001")
        #expect(fetched != nil)
        #expect(fetched?.id == "m-001")
        #expect(fetched?.title == "First Native Meeting")
        #expect(fetched?.isProcessed == true)

        // Fetch All
        let all = try db.fetchAllMeetings()
        #expect(all.count == 1)
        #expect(all.first?.id == "m-001")

        // Delete
        try db.deleteMeeting(id: "m-001")
        let afterDelete = try db.fetchMeeting(id: "m-001")
        #expect(afterDelete == nil)
    }

    @Test("Transcript turns insertion and ordering")
    func testTranscriptTurns() throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "m-002"

        // Insert parent meeting first to satisfy foreign key
        try db.saveMeeting(Meeting(id: meetingId, title: "Interview Session"))

        let turn1 = TranscriptTurn(
            meetingId: meetingId,
            speaker: "Interviewer",
            content: "Welcome to the interview.",
            timestampMs: 1000
        )
        let turn2 = TranscriptTurn(
            meetingId: meetingId,
            speaker: "Candidate",
            content: "Thank you, glad to be here.",
            timestampMs: 3500
        )

        try db.saveTranscriptTurn(turn1)
        try db.saveTranscriptTurn(turn2)

        let turns = try db.fetchTranscripts(for: meetingId)
        #expect(turns.count == 2)
        #expect(turns[0].speaker == "Interviewer")
        #expect(turns[1].speaker == "Candidate")
        #expect(turns[0].timestampMs < turns[1].timestampMs)
    }

    @Test("AI Interactions storage and retrieval")
    func testAIInteractions() throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "m-003"

        // Insert parent meeting first to satisfy foreign key
        try db.saveMeeting(Meeting(id: meetingId, title: "Tech QA Session"))

        let interaction = AIInteraction(
            meetingId: meetingId,
            type: "what_to_answer",
            timestamp: 5000,
            userQuery: "How does ScreenCaptureKit work?",
            aiResponse: "ScreenCaptureKit provides high-performance, low-latency screen and audio capture."
        )

        try db.saveAIInteraction(interaction)

        let list = try db.fetchAIInteractions(for: meetingId)
        #expect(list.count == 1)
        #expect(list.first?.type == "what_to_answer")
        #expect(list.first?.userQuery == "How does ScreenCaptureKit work?")
    }

    @Test("Modes management and active mode toggling")
    func testModes() throws {
        let db = try AppDatabase.makeInMemory()

        let mode1 = Mode(id: "mode-tech", name: "Technical Interview", prompt: "You are a tech interview coach", isCustom: false, isActive: true)
        let mode2 = Mode(id: "mode-sales", name: "Sales Pitch", prompt: "You are a sales coach", isCustom: false, isActive: false)

        try db.saveMode(mode1)
        try db.saveMode(mode2)

        let active = try db.fetchActiveMode()
        #expect(active?.id == "mode-tech")

        // Switch active mode
        try db.setActiveMode(id: "mode-sales")
        let newActive = try db.fetchActiveMode()
        #expect(newActive?.id == "mode-sales")
    }

    @Test("AppState key-value storage")
    func testAppState() throws {
        let db = try AppDatabase.makeInMemory()

        #expect(try db.getAppState(key: "theme") == nil)

        try db.setAppState(key: "theme", value: "liquid-glass-dark")
        #expect(try db.getAppState(key: "theme") == "liquid-glass-dark")

        try db.setAppState(key: "theme", value: nil)
        #expect(try db.getAppState(key: "theme") == nil)
    }

    @Test("Default modes seeding and mode deletion")
    func testDefaultModesSeedingAndDeletion() throws {
        let db = try AppDatabase.makeInMemory()

        // Seed 11 default modes
        try db.seedDefaultModesIfEmpty()
        let modes = try db.fetchModes()
        #expect(modes.count == 11)

        let active = try db.fetchActiveMode()
        #expect(active != nil)
        #expect(active?.id == "mode-tech-interview")

        // Add custom mode and delete it
        let customMode = Mode(id: "custom-negotiation", name: "Custom Negotiation", prompt: "Negotiate salary", isCustom: true, isActive: false)
        try db.saveMode(customMode)
        #expect(try db.fetchModes().count == 12)

        try db.deleteMode(id: "custom-negotiation")
        #expect(try db.fetchModes().count == 11)
        #expect(try db.fetchMode(id: "custom-negotiation") == nil)

        // Add active custom mode and delete it - verify fallback activates another mode
        let activeCustom = Mode(id: "custom-active", name: "Custom Active", prompt: "Active", isCustom: true, isActive: true)
        try db.saveMode(activeCustom)
        try db.setActiveMode(id: "custom-active")
        #expect(try db.fetchActiveMode()?.id == "custom-active")

        try db.deleteMode(id: "custom-active")
        let fallbackActive = try db.fetchActiveMode()
        #expect(fallbackActive != nil)
        #expect(fallbackActive?.id != "custom-active")
    }
}
