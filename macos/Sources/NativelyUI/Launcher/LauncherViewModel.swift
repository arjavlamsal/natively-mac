import SwiftUI
import Combine
import NativelyCore
import NativelyDatabase
import NativelySecurity
import NativelyCompanion
import NativelyRAG

/// Date group for grouping meetings in the sidebar.
public struct MeetingDateGroup: Identifiable {
    public var id: String { title }
    public let title: String
    public let meetings: [Meeting]
    
    public init(title: String, meetings: [Meeting]) {
        self.title = title
        self.meetings = meetings
    }
}

/// View model driving the native macOS Launcher dashboard.
@MainActor
public final class LauncherViewModel: ObservableObject {
    
    // Database and services
    public let database: AppDatabase
    public let companionServer: CompanionServer
    public let ragRetriever: RAGRetriever
    
    // UI State
    @Published public var meetings: [Meeting] = []
    @Published public var searchText: String = ""
    @Published public var selectedMeeting: Meeting? = nil
    @Published public var selectedMeetingTranscripts: [TranscriptTurn] = []
    @Published public var selectedMeetingInteractions: [AIInteraction] = []
    @Published public var isMeetingActive: Bool = false
    @Published public var activeMeetingId: String? = nil
    @Published public var isSettingsPresented: Bool = false
    
    // Settings State
    @Published public var anthropicKey: String = ""
    @Published public var openAIKey: String = ""
    @Published public var geminiKey: String = ""
    @Published public var groqKey: String = ""
    @Published public var deepSeekKey: String = ""
    
    public init(
        database: AppDatabase = .shared,
        companionServer: CompanionServer = CompanionServer(port: 4123)
    ) {
        self.database = database
        self.companionServer = companionServer
        self.ragRetriever = RAGRetriever(database: database)
        
        loadMeetings()
        loadKeychainKeys()
        
        // Start companion micro-server
        try? companionServer.start()
    }
    
    /// Loads all meetings ordered by recency.
    public func loadMeetings() {
        do {
            self.meetings = try database.fetchAllMeetings()
            if selectedMeeting == nil, let first = meetings.first {
                selectMeeting(first)
            }
        } catch {
            self.meetings = []
        }
    }
    
    /// Selects a meeting and fetches its transcripts and AI interactions.
    public func selectMeeting(_ meeting: Meeting) {
        self.selectedMeeting = meeting
        do {
            self.selectedMeetingTranscripts = try database.fetchTranscripts(for: meeting.id)
            self.selectedMeetingInteractions = try database.fetchAIInteractions(for: meeting.id)
        } catch {
            self.selectedMeetingTranscripts = []
            self.selectedMeetingInteractions = []
        }
    }
    
    /// Groups meetings by "Today", "Yesterday", and "Earlier".
    public var groupedMeetings: [MeetingDateGroup] {
        let filtered = searchText.isEmpty ? meetings : meetings.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.summaryJson ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        var todayMeetings: [Meeting] = []
        var yesterdayMeetings: [Meeting] = []
        var earlierMeetings: [Meeting] = []
        
        for meeting in filtered {
            let meetingDate: Date
            if let start = meeting.startTime {
                meetingDate = Date(timeIntervalSince1970: Double(start) / 1000.0)
            } else {
                meetingDate = Date()
            }
            
            if meetingDate >= today {
                todayMeetings.append(meeting)
            } else if meetingDate >= yesterday {
                yesterdayMeetings.append(meeting)
            } else {
                earlierMeetings.append(meeting)
            }
        }
        
        var groups: [MeetingDateGroup] = []
        if !todayMeetings.isEmpty { groups.append(MeetingDateGroup(title: "Today", meetings: todayMeetings)) }
        if !yesterdayMeetings.isEmpty { groups.append(MeetingDateGroup(title: "Yesterday", meetings: yesterdayMeetings)) }
        if !earlierMeetings.isEmpty { groups.append(MeetingDateGroup(title: "Earlier", meetings: earlierMeetings)) }
        
        return groups
    }
    
    // Meeting Lifecycle Callbacks (Wired to AppCoordinator)
    public var onStartMeeting: (@MainActor () -> Void)?
    public var onStopMeeting: (@MainActor () -> Void)?
    
    /// Toggles the active meeting session.
    public func toggleMeetingSession() {
        if isMeetingActive {
            stopMeeting()
        } else {
            startMeeting()
        }
    }
    
    public func startMeeting() {
        if let onStartMeeting {
            onStartMeeting()
            return
        }
        
        let meetingId = "mtg-\(UUID().uuidString)"
        self.activeMeetingId = meetingId
        self.isMeetingActive = true
        self.companionServer.isMeetingActive = true
        
        let newMeeting = Meeting(
            id: meetingId,
            title: "Meeting - \(Date().formatted(date: .abbreviated, time: .shortened))",
            startTime: Int64(Date().timeIntervalSince1970 * 1000),
            durationMs: 0,
            summaryJson: nil,
            createdAt: Date().ISO8601Format(),
            calendarEventId: nil,
            source: "native",
            isProcessed: true,
            summaryStatus: "recording"
        )
        try? database.saveMeeting(newMeeting)
        loadMeetings()
        selectMeeting(newMeeting)
    }
    
    public func stopMeeting() {
        if let onStopMeeting {
            onStopMeeting()
            return
        }
        
        guard let activeId = activeMeetingId else { return }
        self.isMeetingActive = false
        self.companionServer.isMeetingActive = false
        
        if var current = try? database.fetchMeeting(id: activeId) {
            let start = current.startTime ?? Int64(Date().timeIntervalSince1970 * 1000)
            current.durationMs = Int64(Date().timeIntervalSince1970 * 1000) - start
            current.summaryStatus = "completed"
            try? database.saveMeeting(current)
        }
        
        self.activeMeetingId = nil
        loadMeetings()
    }
    
    /// Deletes a meeting and refreshes list.
    public func deleteMeeting(_ meeting: Meeting) {
        try? database.deleteMeeting(id: meeting.id)
        if selectedMeeting?.id == meeting.id {
            selectedMeeting = nil
            selectedMeetingTranscripts = []
            selectedMeetingInteractions = []
        }
        loadMeetings()
    }
    
    /// Loads Keychain API keys.
    public func loadKeychainKeys() {
        Task { [weak self] in
            let kc = KeychainManager.shared
            let anthropic = (try? await kc.get(key: "anthropic_api_key")) ?? ""
            let openai = (try? await kc.get(key: "openai_api_key")) ?? ""
            let gemini = (try? await kc.get(key: "gemini_api_key")) ?? ""
            let groq = (try? await kc.get(key: "groq_api_key")) ?? ""
            let deepseek = (try? await kc.get(key: "deepseek_api_key")) ?? ""
            
            await MainActor.run {
                self?.anthropicKey = anthropic
                self?.openAIKey = openai
                self?.geminiKey = gemini
                self?.groqKey = groq
                self?.deepSeekKey = deepseek
            }
        }
    }
    
    /// Saves updated Keychain API keys.
    public func saveKeychainKey(name: String, value: String) {
        Task {
            let kc = KeychainManager.shared
            if value.trimmingCharacters(in: .whitespaces).isEmpty {
                _ = try? await kc.delete(key: name)
            } else {
                try? await kc.save(key: name, value: value)
            }
        }
    }
    
    // Meeting Chat (Ask About This Meeting)
    @Published public var meetingChatMessages: [OverlayMessage] = []
    @Published public var isMeetingChatStreaming: Bool = false
    
    /// Updates a meeting's title in the database and active view.
    public func updateMeetingTitle(id: String, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var current = try? database.fetchMeeting(id: id) {
            current.title = trimmed
            try? database.saveMeeting(current)
            if selectedMeeting?.id == id {
                selectedMeeting?.title = trimmed
            }
            loadMeetings()
        }
    }
    
    /// Interactive Q&A chat about the selected meeting using RAG context retrieval.
    public func askAboutSelectedMeeting(question: String) {
        guard let meeting = selectedMeeting else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        meetingChatMessages.append(OverlayMessage(role: .user, text: trimmed))
        
        let assistantId = UUID().uuidString
        meetingChatMessages.append(OverlayMessage(id: assistantId, role: .assistant, text: "", isStreaming: true, providerName: "Natively RAG", modelName: "Meeting Intelligence"))
        isMeetingChatStreaming = true
        
        Task { [weak self] in
            guard let self = self else { return }
            let retrievedChunks = (try? self.ragRetriever.searchLexical(query: trimmed, meetingId: meeting.id, topK: 4)) ?? []
            
            var answer = ""
            if !retrievedChunks.isEmpty {
                answer = "Based on this meeting's discussion:\n\n"
                for (idx, chunk) in retrievedChunks.enumerated() {
                    answer += "**\(idx + 1). Relevant Discussion**: \"\(chunk.text.prefix(180))...\"\n\n"
                }
                answer += "To answer your question directly: The key discussion points covered during this session align with the retrieved excerpts above."
            } else if !self.selectedMeetingTranscripts.isEmpty {
                let matches = self.selectedMeetingTranscripts.filter { $0.content.localizedCaseInsensitiveContains(trimmed) }
                if !matches.isEmpty {
                    answer = "Found \(matches.count) mention(s) in the transcript:\n\n"
                    for match in matches.prefix(3) {
                        answer += "- **\(match.speaker)**: \"\(match.content)\"\n"
                    }
                } else {
                    answer = "No exact keyword matches found in this meeting transcript for \"\(trimmed)\". The meeting covered: \(meeting.parsedSummary?.overview ?? meeting.title ?? "General conversation")."
                }
            } else {
                answer = "No transcripts or notes are available for this meeting yet."
            }
            
            await MainActor.run {
                if let idx = self.meetingChatMessages.firstIndex(where: { $0.id == assistantId }) {
                    self.meetingChatMessages[idx].text = answer
                    self.meetingChatMessages[idx].isStreaming = false
                }
                self.isMeetingChatStreaming = false
            }
        }
    }
    
    /// Formats meeting content into Markdown for export.
    public func exportMeetingMarkdown(_ meeting: Meeting) -> String {
        var doc = "# \(meeting.title ?? "Meeting")\n"
        doc += "**Date**: \(meeting.createdAt ?? "")\n"
        if let duration = meeting.durationMs {
            doc += "**Duration**: \(duration / 60000) minutes\n"
        }
        doc += "\n---\n\n"
        
        if let summary = meeting.parsedSummary {
            if let items = summary.actionItems, !items.isEmpty {
                doc += "## Action Items\n"
                for item in items {
                    doc += "- [ ] \(item)\n"
                }
                doc += "\n"
            }
            if let points = summary.keyPoints, !points.isEmpty {
                doc += "## Key Points\n"
                for point in points {
                    doc += "- \(point)\n"
                }
                doc += "\n"
            }
        }
        
        if !selectedMeetingTranscripts.isEmpty {
            doc += "## Transcript\n"
            for turn in selectedMeetingTranscripts {
                doc += "**\(turn.speaker)**: \(turn.content)\n\n"
            }
        }
        
        return doc
    }
}
