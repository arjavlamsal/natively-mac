import Testing
import Foundation
@testable import NativelyCore
@testable import NativelyDatabase
@testable import NativelyCompanion
@testable import NativelyUI

@Suite("NativelyUI Launcher Tests")
struct LauncherTests {
    
    @Test("LauncherViewModel loads and groups meetings by date")
    @MainActor
    func testMeetingGroupingAndSearch() throws {
        let db = try AppDatabase.makeInMemory()
        
        let m1 = Meeting(
            id: "m1",
            title: "Frontend Engineering Sync",
            startTime: Int64(Date().timeIntervalSince1970 * 1000), // Today
            durationMs: 1800000,
            summaryJson: "Discussed view transitions and metal performance.",
            source: "native"
        )
        let m2 = Meeting(
            id: "m2",
            title: "Executive Staff Review",
            startTime: Int64((Date().timeIntervalSince1970 - 86400 * 2) * 1000), // 2 days ago
            durationMs: 3600000,
            summaryJson: "Reviewed quarterly hiring roadmap.",
            source: "native"
        )
        
        try db.saveMeeting(m1)
        try db.saveMeeting(m2)
        
        let vm = LauncherViewModel(database: db, companionServer: CompanionServer(port: 4199))
        #expect(vm.meetings.count == 2)
        
        let groups = vm.groupedMeetings
        #expect(!groups.isEmpty)
        
        // Search test
        vm.searchText = "Frontend"
        let filteredGroups = vm.groupedMeetings
        #expect(filteredGroups.first?.meetings.first?.title == "Frontend Engineering Sync")
        
        // Start meeting toggle
        vm.startMeeting()
        #expect(vm.isMeetingActive == true)
        #expect(vm.activeMeetingId != nil)
        
        // Stop meeting toggle
        vm.stopMeeting()
        #expect(vm.isMeetingActive == false)
        #expect(vm.activeMeetingId == nil)
        
        // Delete meeting
        vm.deleteMeeting(m1)
        #expect(vm.meetings.contains { $0.id == "m1" } == false)
    }
    
    @Test("LauncherViewModel exports meeting notes to formatted Markdown")
    @MainActor
    func testMarkdownExport() throws {
        let db = try AppDatabase.makeInMemory()
        let meeting = Meeting(
            id: "export-test",
            title: "Product Architecture Review",
            startTime: 100000,
            durationMs: 1200000,
            summaryJson: "Discussed native architecture.",
            source: "native"
        )
        try db.saveMeeting(meeting)
        
        let turn = TranscriptTurn(
            meetingId: "export-test",
            speaker: "Arjav",
            content: "We should eliminate electron webviews.",
            timestampMs: 100005
        )
        try db.saveTranscriptTurn(turn)
        
        let vm = LauncherViewModel(database: db, companionServer: CompanionServer(port: 4198))
        vm.selectMeeting(meeting)
        let md = vm.exportMeetingMarkdown(meeting)
        #expect(md.contains("# Product Architecture Review"))
        #expect(md.contains("## Transcript"))
        #expect(md.contains("**Arjav**: We should eliminate electron webviews."))
    }
}
