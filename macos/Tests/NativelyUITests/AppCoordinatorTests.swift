import Testing
import Foundation
import AppKit
import NativelyCore
import NativelyDatabase
import NativelyCompanion
import NativelyRAG
@testable import NativelyUI

@Suite("AppCoordinator and System Integration Tests")
struct AppCoordinatorTests {
    
    @Test("AppCoordinator initializes and coordinates services")
    @MainActor
    func testCoordinatorInitAndModes() throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4192)
        
        #expect(!coordinator.isMeetingActive)
        #expect(coordinator.activeMeeting == nil)
        
        coordinator.start()
        
        // Mode switching
        let customMode = Mode(
            id: "mode-system-arch",
            name: "Systems Architecture",
            prompt: "Focus on low latency, zero allocations, and thread safety.",
            isCustom: true,
            isActive: false
        )
        try db.saveMode(customMode)
        
        coordinator.switchMode(customMode)
        #expect(coordinator.overlayWindowManager.viewModel.activeMode.id == "mode-system-arch")
        
        coordinator.shutdown()
    }
    
    @Test("Meeting lifecycle manages database persistence and menu bar state")
    @MainActor
    func testMeetingLifecycle() async throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4193)
        coordinator.start()
        
        // 1. Start meeting
        coordinator.startMeetingSession(title: "Executive Architecture Review")
        #expect(coordinator.isMeetingActive == true)
        #expect(coordinator.activeMeeting != nil)
        
        guard let meetingId = coordinator.activeMeeting?.id else {
            Issue.record("Expected active meeting ID")
            return
        }
        
        #expect(coordinator.overlayWindowManager.viewModel.currentMeetingId == meetingId)
        
        // 2. Append live transcripts
        coordinator.overlayWindowManager.viewModel.appendTranscript(
            speaker: "CEO",
            text: "Welcome everyone, let us discuss native app performance."
        )
        coordinator.overlayWindowManager.viewModel.appendTranscript(
            speaker: "CTO",
            text: "We eliminated all Electron overhead and reduced memory by 95%."
        )
        
        let turns = try db.fetchTranscripts(for: meetingId)
        #expect(turns.count == 2)
        #expect(turns[0].speaker == "CEO")
        #expect(turns[1].speaker == "CTO")
        
        // 3. Stop meeting
        let stoppedMeeting = await coordinator.stopMeetingSession()
        #expect(coordinator.isMeetingActive == false)
        #expect(coordinator.activeMeeting == nil)
        #expect(stoppedMeeting != nil)
        #expect(stoppedMeeting?.durationMs != nil)
        
        // Verify persisted meeting in database
        let fetchedMeeting = try db.fetchMeeting(id: meetingId)
        #expect(fetchedMeeting != nil)
        #expect(fetchedMeeting?.title == "Executive Architecture Review")
        
        coordinator.shutdown()
    }
    
    @Test("Launcher Start Natively auto-shows overlay, enforces stealth, and overlay Stop button ends session")
    @MainActor
    func testLauncherAndOverlayButtonLifecycle() async throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4195)
        coordinator.start()
        
        #expect(coordinator.isMeetingActive == false)
        #expect(coordinator.launcherWindowManager.viewModel.isMeetingActive == false)
        
        // 1. User clicks "Start Natively" in Launcher
        coordinator.launcherWindowManager.viewModel.startMeeting()
        
        #expect(coordinator.isMeetingActive == true)
        #expect(coordinator.launcherWindowManager.viewModel.isMeetingActive == true)
        #expect(coordinator.launcherWindowManager.viewModel.activeMeetingId != nil)
        #expect(coordinator.overlayWindowManager.viewModel.isExpanded == true)
        #expect(coordinator.overlayWindowManager.panel != nil)
        #expect(coordinator.overlayWindowManager.panel?.sharingType == NSWindow.SharingType.none)
        
        // 2. User clicks red Stop button in Overlay TopPill
        guard let onEndMeeting = coordinator.overlayWindowManager.viewModel.onEndMeeting else {
            Issue.record("Expected onEndMeeting callback to be wired by AppCoordinator")
            return
        }
        
        onEndMeeting()
        
        // Allow brief time for async stop meeting task
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(coordinator.isMeetingActive == false)
        #expect(coordinator.launcherWindowManager.viewModel.isMeetingActive == false)
        #expect(coordinator.launcherWindowManager.viewModel.activeMeetingId == nil)
        #expect(coordinator.overlayWindowManager.viewModel.isExpanded == false)
        
        // Verify database holds completed meeting
        let allMeetings = try db.fetchAllMeetings()
        #expect(!allMeetings.isEmpty)
        #expect(allMeetings.first?.summaryStatus == "completed")
        
        coordinator.shutdown()
    }
    
    @Test("Companion DOM context callback feeds active overlay context")
    @MainActor
    func testCompanionDOMHookup() async throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4194)
        coordinator.start()
        
        // Trigger companion DOM payload
        let payload = DOMContextPayload(
            title: "LeetCode 42 - Trapping Rain Water",
            url: "https://leetcode.com/problems/trapping-rain-water/",
            text: "Given n non-negative integers representing an elevation map...",
            dom: "<main>...</main>"
        )
        
        coordinator.companionServer.onDOMCaptured?(payload)
        
        // Allow brief time for MainActor task
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(coordinator.overlayWindowManager.viewModel.attachedOCRSnippet?.contains("Trapping Rain Water") == true ||
                coordinator.overlayWindowManager.viewModel.attachedOCRSnippet?.contains("elevation map") == true)
        
        coordinator.shutdown()
    }
    
    @Test("PermissionsManager safely checks authorization statuses")
    @MainActor
    func testPermissionsManager() {
        let pm = PermissionsManager.shared
        pm.checkAllPermissions()
        
        // Should evaluate without crashing
        _ = pm.hasScreenRecordingPermission
        _ = pm.hasMicrophonePermission
        _ = pm.hasAccessibilityPermission
    }
    
    @Test("Longevity & Stress: 50 meeting sessions with transcripts and vector chunks")
    func testLongevityStressSimulation() throws {
        let db = try AppDatabase.makeInMemory()
        let retriever = RAGRetriever(database: db)
        
        // Stress test inserting and querying across 50 simulated sessions
        for i in 1...50 {
            let meetingId = "stress-m-\(i)"
            let meeting = Meeting(
                id: meetingId,
                title: "Stress Meeting \(i)",
                durationMs: 3600000,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                source: "native"
            )
            try db.saveMeeting(meeting)
            
            var turns: [TranscriptTurn] = []
            for t in 0..<10 {
                let turn = TranscriptTurn(
                    meetingId: meetingId,
                    speaker: t % 2 == 0 ? "Speaker A" : "Speaker B",
                    content: "Turn content #\(t) for meeting \(i) discussing native macOS performance and memory.",
                    timestampMs: Int64(t * 1000)
                )
                turns.append(turn)
                try db.saveTranscriptTurn(turn)
            }
            
            let chunks = SemanticChunker.chunkTranscripts(turns, maxWordsPerChunk: 30)
            var vectorChunks: [VectorChunk] = []
            for (idx, c) in chunks.enumerated() {
                vectorChunks.append(VectorChunk(
                    id: "\(meetingId)-c\(idx)",
                    meetingId: meetingId,
                    chunkIndex: idx,
                    text: c.text,
                    embedding: [Float(idx) * 0.1, 0.5, 0.2],
                    timestampMs: Int64(idx * 2000)
                ))
            }
            try db.saveVectorChunks(vectorChunks)
        }
        
        // Verify database holds all 50 meetings
        let allMeetings = try db.fetchAllMeetings()
        #expect(allMeetings.count == 50)
        
        // Verify high-throughput vector retrieval under stress
        let queryEmbedding: [Float] = [0.1, 0.5, 0.2]
        let retrieved = try retriever.retrieveSimilar(queryEmbedding: queryEmbedding, topK: 5, minSimilarity: 0.1)
        #expect(!retrieved.isEmpty)
        #expect(retrieved.count <= 5)
        
        // Verify cascade deletion
        try db.deleteMeeting(id: "stress-m-1")
        let chunksRemaining = try db.fetchVectorChunks(meetingId: "stress-m-1")
        #expect(chunksRemaining.isEmpty)
    }
    
    @Test("Universal stealth mode applies sharingType = .none to all app windows including Launcher")
    @MainActor
    func testUniversalStealthModeAcrossAllWindows() throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4196)
        coordinator.start()
        
        // Show launcher window
        coordinator.launcherWindowManager.showLauncher()
        guard let launcherWindow = coordinator.launcherWindowManager.window else {
            Issue.record("Expected launcher window to be initialized")
            return
        }
        
        #expect(launcherWindow.sharingType == NSWindow.SharingType.none)
        
        // Enable stealth mode explicitly
        coordinator.setStealthMode(true)
        #expect(launcherWindow.sharingType == NSWindow.SharingType.none)
        
        // Create an arbitrary test window and verify applyStealthPolicy
        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        testWindow.applyStealthPolicy()
        #expect(testWindow.sharingType == NSWindow.SharingType.none)
        
        coordinator.shutdown()
    }
    
    @Test("OverlayViewModel stopMeeting cleanly resets state and dismisses session")
    @MainActor
    func testOverlayStopMeetingResetsState() async throws {
        let db = try AppDatabase.makeInMemory()
        let coordinator = AppCoordinator(database: db, companionPort: 4197)
        coordinator.start()
        
        coordinator.startMeetingSession(title: "Direct Stop Test")
        #expect(coordinator.isMeetingActive == true)
        #expect(coordinator.overlayWindowManager.viewModel.isMeetingActive == true)
        
        // Directly trigger stopMeeting on the OverlayViewModel as done by TopPillBarView
        coordinator.overlayWindowManager.viewModel.stopMeeting()
        
        try? await Task.sleep(nanoseconds: 150_000_000)
        
        #expect(coordinator.isMeetingActive == false)
        #expect(coordinator.overlayWindowManager.viewModel.isMeetingActive == false)
        #expect(coordinator.overlayWindowManager.viewModel.currentMeetingId == nil)
        
        coordinator.shutdown()
    }
}
