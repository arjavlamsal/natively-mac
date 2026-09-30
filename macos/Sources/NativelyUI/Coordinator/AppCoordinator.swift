import AppKit
import SwiftUI
import NativelyCore
import NativelyDatabase
import NativelySecurity
import NativelyAudio
import NativelyVision
import NativelyAI
import NativelyCompanion
import NativelyRAG

/// Central coordinator that orchestrates the entire native macOS application lifecycle:
/// binds audio, vision, AI streaming, stealth overlay, launcher dashboard, companion server, and menu bar.
@MainActor
public final class AppCoordinator: ObservableObject {
    public static let shared = AppCoordinator()
    
    // Services
    public let database: AppDatabase
    public let companionServer: CompanionServer
    public let overlayWindowManager: OverlayWindowManager
    public let launcherWindowManager: LauncherWindowManager
    public let menuBarController: MenuBarController
    public let permissionsManager: PermissionsManager
    public let hotkeyManager: HotkeyManager
    public let screenVisionCoordinator: ScreenVisionCoordinator
    public let audioCoordinator: DualChannelAudioCoordinator
    public let ragRetriever: RAGRetriever
    public let turnPlanner: TurnPlannerActor
    
    // Meeting Session State
    @Published public private(set) var isMeetingActive: Bool = false
    @Published public private(set) var activeMeeting: Meeting?
    private var meetingStartTime: Date?
    
    public init(
        database: AppDatabase = .shared,
        companionPort: UInt16 = 4123,
        overlayWindowManager: OverlayWindowManager? = nil,
        launcherWindowManager: LauncherWindowManager? = nil
    ) {
        self.database = database
        self.companionServer = CompanionServer(port: companionPort)
        self.overlayWindowManager = overlayWindowManager ?? (database === AppDatabase.shared ? .shared : OverlayWindowManager(database: database))
        self.launcherWindowManager = launcherWindowManager ?? (database === AppDatabase.shared ? .shared : LauncherWindowManager(database: database))
        self.menuBarController = MenuBarController.shared
        self.permissionsManager = PermissionsManager.shared
        self.hotkeyManager = HotkeyManager.shared
        self.screenVisionCoordinator = ScreenVisionCoordinator()
        self.audioCoordinator = DualChannelAudioCoordinator(database: database)
        self.ragRetriever = RAGRetriever(database: database)
        self.turnPlanner = TurnPlannerActor(database: database)
    }
    
    /// Initializes and starts all coordinators, windows, servers, and hotkeys.
    public func start() {
        // 1. Configure Overlay & TurnPlanner
        overlayWindowManager.viewModel.configureTurnPlanner(planner: turnPlanner)
        overlayWindowManager.screenVisionCoordinator = screenVisionCoordinator
        
        overlayWindowManager.viewModel.onEndMeeting = { [weak self] in
            Task {
                _ = await self?.stopMeetingSession()
            }
        }
        overlayWindowManager.viewModel.onOpenLauncher = { [weak self] in
            self?.launcherWindowManager.showLauncher()
        }
        overlayWindowManager.viewModel.onCropTrigger = { [weak self] in
            self?.overlayWindowManager.handleCropTrigger()
        }
        
        // Wire Launcher Dashboard Meeting Actions
        launcherWindowManager.viewModel.onStartMeeting = { [weak self] in
            self?.startMeetingSession()
        }
        launcherWindowManager.viewModel.onStopMeeting = { [weak self] in
            Task {
                _ = await self?.stopMeetingSession()
            }
        }
        
        // 2. Setup System Menu Bar
        menuBarController.setupMenuBar()
        setupMenuBarBindings()
        
        // 3. Setup Global Hotkeys
        setupHotkeyBindings()
        hotkeyManager.registerDefaultHotkeys()
        
        // 4. Start Companion Micro-Server
        setupCompanionServer()
        
        // 5. Initial Modes sync
        syncModes()
        
        // 6. Check System Permissions
        permissionsManager.checkAllPermissions()
        
        // 7. Setup Audio Turn Handler
        Task { [weak self] in
            guard let self else { return }
            await self.audioCoordinator.setTurnHandler { [weak self] turn in
                Task { @MainActor in
                    self?.overlayWindowManager.viewModel.appendTranscript(speaker: turn.speaker, text: turn.content)
                }
            }
        }
    }
    
    /// Shuts down all active servers, monitors, and session engines.
    public func shutdown() {
        companionServer.stop()
        hotkeyManager.unregisterAll()
        overlayWindowManager.hideOverlay()
        launcherWindowManager.hideLauncher()
        Task { [weak self] in
            await self?.audioCoordinator.stopMeeting()
        }
    }
    
    // MARK: - Companion Server Hookup
    
    private func setupCompanionServer() {
        companionServer.onDOMCaptured = { [weak self] payload in
            Task { @MainActor in
                if let text = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    self?.overlayWindowManager.viewModel.attachScreenContext(
                        ocrText: text,
                        imageBase64: nil
                    )
                }
                if let url = payload.url, let text = payload.text, !text.isEmpty {
                    self?.overlayWindowManager.viewModel.attachWebContext(
                        url: url,
                        title: payload.title ?? url,
                        charCount: text.count
                    )
                }
            }
        }
        
        try? companionServer.start()
    }
    
    // MARK: - Menu Bar Bindings
    
    private func setupMenuBarBindings() {
        menuBarController.onToggleOverlay = { [weak self] in
            self?.overlayWindowManager.toggleVisibility()
        }
        
        menuBarController.onTriggerCrop = { [weak self] in
            self?.overlayWindowManager.handleCropTrigger()
        }
        
        menuBarController.onOpenDashboard = { [weak self] in
            self?.launcherWindowManager.showLauncher()
        }
        
        menuBarController.onToggleMeeting = { [weak self] in
            self?.toggleMeetingSession()
        }
        
        menuBarController.onSelectMode = { [weak self] mode in
            self?.switchMode(mode)
        }
        
        menuBarController.onOpenSettings = { [weak self] in
            self?.launcherWindowManager.showLauncher()
        }
    }
    
    // MARK: - Global Hotkey Bindings
    
    private func setupHotkeyBindings() {
        hotkeyManager.onAction(.toggleVisibility) { [weak self] in
            self?.overlayWindowManager.toggleVisibility()
        }
        
        hotkeyManager.onAction(.toggleMousePassthrough) { [weak self] in
            self?.overlayWindowManager.toggleMousePassthrough()
        }
        
        hotkeyManager.onAction(.triggerCrop) { [weak self] in
            self?.overlayWindowManager.handleCropTrigger()
        }
        
        hotkeyManager.onAction(.processScreenshots) { [weak self] in
            self?.overlayWindowManager.focusPromptInput()
        }
        
        // Presets 1-7
        hotkeyManager.onAction(.quickAction1) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 1) }
        hotkeyManager.onAction(.quickAction2) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 2) }
        hotkeyManager.onAction(.quickAction3) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 3) }
        hotkeyManager.onAction(.quickAction4) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 4) }
        hotkeyManager.onAction(.quickAction5) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 5) }
        hotkeyManager.onAction(.quickAction6) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 6) }
        hotkeyManager.onAction(.quickAction7) { [weak self] in self?.overlayWindowManager.viewModel.triggerQuickAction(presetNumber: 7) }
    }
    
    // MARK: - Meeting Lifecycle
    
    public func toggleMeetingSession() {
        if isMeetingActive {
            Task {
                _ = await stopMeetingSession()
            }
        } else {
            startMeetingSession()
        }
    }
    
    public func startMeetingSession(title: String = "Meeting") {
        let meetingId = "mtg-\(UUID().uuidString.prefix(8))"
        let displayTitle = (title == "Meeting") ? "Meeting - \(Date().formatted(date: .abbreviated, time: .shortened))" : title
        let meeting = Meeting(
            id: meetingId,
            title: displayTitle,
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            durationMs: 0,
            summaryJson: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            calendarEventId: nil,
            source: "native",
            isProcessed: true,
            summaryStatus: "recording"
        )
        
        try? database.saveMeeting(meeting)
        self.activeMeeting = meeting
        self.meetingStartTime = Date()
        self.isMeetingActive = true
        
        // 1. Sync Launcher Dashboard State
        launcherWindowManager.viewModel.isMeetingActive = true
        launcherWindowManager.viewModel.activeMeetingId = meetingId
        launcherWindowManager.viewModel.loadMeetings()
        launcherWindowManager.viewModel.selectMeeting(meeting)
        
        // 2. Sync Companion Server
        companionServer.isMeetingActive = true
        
        // 3. Enforce Hardware Stealth Mode (sharingType = .none)
        UserDefaults.standard.set(true, forKey: "natively_undetectable")
        overlayWindowManager.setStealthMode(true)
        
        // 4. Automatically Show & Expand Stealth Overlay
        overlayWindowManager.viewModel.currentMeetingId = meetingId
        overlayWindowManager.viewModel.isExpanded = true
        overlayWindowManager.showOverlay()
        
        // 5. Update System Menu Bar
        menuBarController.setMeetingState(isActive: true, title: displayTitle)
        
        // 6. Start Native Dual-Channel Audio Capture
        Task { [weak self] in
            try? await self?.audioCoordinator.startMeeting(id: meetingId)
        }
    }
    
    public func stopMeetingSession() async -> Meeting? {
        guard isMeetingActive, var meeting = activeMeeting else { return nil }
        
        // 1. Immediately update reactive UI state and persist completed status on MainActor
        self.isMeetingActive = false
        self.activeMeeting = nil
        let startTime = self.meetingStartTime
        self.meetingStartTime = nil
        
        let durationMs: Int64
        if let startTime {
            durationMs = Int64(Date().timeIntervalSince(startTime) * 1000)
        } else {
            durationMs = 0
        }
        meeting.durationMs = durationMs
        meeting.summaryStatus = "completed"
        try? database.saveMeeting(meeting)
        
        launcherWindowManager.viewModel.isMeetingActive = false
        launcherWindowManager.viewModel.activeMeetingId = nil
        launcherWindowManager.viewModel.loadMeetings()
        launcherWindowManager.viewModel.selectMeeting(meeting)
        
        overlayWindowManager.viewModel.currentMeetingId = nil
        withAnimation(NativelyTheme.smoothSpring) {
            overlayWindowManager.viewModel.isExpanded = false
        }
        companionServer.isMeetingActive = false
        menuBarController.setMeetingState(isActive: false)
        
        // 2. Stop Audio Recording in background
        await audioCoordinator.stopMeeting()
        
        // 8. Auto-index meeting transcripts into semantic vector chunks for RAG
        let turns = (try? database.fetchTranscripts(for: meeting.id)) ?? []
        if !turns.isEmpty {
            let chunks = SemanticChunker.chunkTranscripts(turns)
            var vectorChunks: [VectorChunk] = []
            for (idx, chunk) in chunks.enumerated() {
                vectorChunks.append(VectorChunk(
                    id: "\(meeting.id)-c\(idx)",
                    meetingId: meeting.id,
                    chunkIndex: idx,
                    text: chunk.text,
                    embedding: nil,
                    timestampMs: Int64(idx * 2000)
                ))
            }
            try? database.saveVectorChunks(vectorChunks)
        }
        
        return meeting
    }
    
    // MARK: - Mode Management
    
    public func switchMode(_ mode: Mode) {
        overlayWindowManager.viewModel.selectMode(mode)
        syncModes()
    }
    
    private func syncModes() {
        let modes = (try? database.fetchModes()) ?? [overlayWindowManager.viewModel.activeMode]
        let activeId = overlayWindowManager.viewModel.activeMode.id
        menuBarController.updateModes(modes, activeId: activeId)
    }
}
