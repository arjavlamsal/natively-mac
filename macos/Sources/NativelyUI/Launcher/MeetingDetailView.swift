import SwiftUI
import AppKit
import NativelyCore

/// Deep inspection view for a selected meeting adhering to macOS HIG.
/// Displays structured notes, diarized transcripts, AI solutions, and an interactive RAG assistant.
public struct MeetingDetailView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    public let meeting: Meeting
    
    @State private var selectedTab: Int = 0
    @State private var isCopied: Bool = false
    @State private var isEditingTitle: Bool = false
    @State private var editableTitle: String = ""
    @State private var transcriptFilter: String = ""
    @State private var chatQuery: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var showFollowUpSheet: Bool = false
    
    public init(viewModel: LauncherViewModel, meeting: Meeting) {
        self.viewModel = viewModel
        self.meeting = meeting
        _editableTitle = State(initialValue: meeting.title ?? "Untitled Meeting")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
                .background(NativelyTheme.borderSubtle)
            
            // Native Segmented Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Notes & Summary").tag(0)
                Text("Transcript (\(viewModel.selectedMeetingTranscripts.count))").tag(1)
                Text("AI Solutions (\(viewModel.selectedMeetingInteractions.count))").tag(2)
                Text("Ask About Meeting").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        summaryTab
                    case 1:
                        transcriptTab
                    case 2:
                        interactionsTab
                    case 3:
                        askMeetingTab
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(NativelyTheme.bgPrimary)
        .onChange(of: meeting.id) { _, _ in
            editableTitle = meeting.title ?? "Untitled Meeting"
            viewModel.meetingChatMessages.removeAll()
        }
        .sheet(isPresented: $showFollowUpSheet) {
            FollowUpDraftSheet(meeting: meeting)
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            // Back Button to return to Launcher
            Button(action: {
                withAnimation(NativelyTheme.smoothSpring) {
                    viewModel.selectedMeeting = nil
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(NativelyTheme.skyAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NativelyTheme.skyAccent.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(NativelyTheme.skyAccent.opacity(0.25), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            
            VStack(alignment: .leading, spacing: 5) {
                // Title & Edit Button
                HStack(spacing: 8) {
                    if isEditingTitle {
                        TextField("Meeting Title", text: $editableTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: 340)
                            .onSubmit {
                                isEditingTitle = false
                                viewModel.updateMeetingTitle(id: meeting.id, newTitle: editableTitle)
                            }
                        
                        Button("Save") {
                            isEditingTitle = false
                            viewModel.updateMeetingTitle(id: meeting.id, newTitle: editableTitle)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Text(meeting.title ?? "Untitled Meeting")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Button(action: {
                            editableTitle = meeting.title ?? "Untitled Meeting"
                            isEditingTitle = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Rename Meeting")
                    }
                }
                
                // Metadata Pills
                HStack(spacing: 8) {
                    Label(formatMeetingDate(meeting.createdAt), systemImage: "calendar")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    
                    if let duration = meeting.durationMs, duration > 0 {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Label("\(duration / 60000) mins", systemImage: "clock")
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundColor(NativelyTheme.emeraldGreen)
                    }
                    
                    if let source = meeting.source {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text(source.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Copy Notes
                Button(action: copyMarkdownExport) {
                    Label(isCopied ? "Copied" : "Copy Notes", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Draft Follow-Up
                Button(action: { showFollowUpSheet = true }) {
                    Label("Draft Follow-Up", systemImage: "envelope.badge")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Export PDF
                Button(action: exportPDF) {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Export TXT
                Button(action: exportPlainText) {
                    Label("Export TXT", systemImage: "doc.text")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Delete
                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.9))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete Meeting")
                .alert("Delete Meeting?", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteMeeting(meeting)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete \"\(meeting.title ?? "this meeting")\"? This action cannot be undone.")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Tab 0: Summary
    
    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let summary = meeting.parsedSummary {
                let actionItems = summary.actionItems ?? []
                let keyPoints = summary.keyPoints ?? []
                
                // Overview
                if let overview = summary.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("EXECUTIVE SUMMARY", systemImage: "text.alignleft")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text(overview)
                            .font(.system(size: 13))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineSpacing(3.5)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .nativeCard()
                    }
                }
                
                // Action Items
                if !actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ACTION ITEMS", systemImage: "checklist")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(NativelyTheme.cyanBlue)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(actionItems, id: \.self) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(NativelyTheme.cyanBlue)
                                        .font(.system(size: 13))
                                        .padding(.top, 1.5)
                                    Text(item)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NativelyTheme.cyanBlue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(NativelyTheme.cyanBlue.opacity(0.18), lineWidth: 0.5)
                        )
                    }
                }
                
                // Key Takeaways
                if !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("KEY TAKEAWAYS", systemImage: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(NativelyTheme.purpleAccent)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(NativelyTheme.purpleAccent)
                                        .frame(width: 5.5, height: 5.5)
                                        .padding(.top, 6)
                                    Text(point)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NativelyTheme.purpleAccent.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(NativelyTheme.purpleAccent.opacity(0.18), lineWidth: 0.5)
                        )
                    }
                }
            } else if let raw = meeting.summaryJson, !raw.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("NOTES", systemImage: "note.text")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(raw)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineSpacing(3.5)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .nativeCard()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No summary recorded for this session.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }
    
    // MARK: - Tab 1: Diarized Transcript
    
    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search / Filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search within transcript...", text: $transcriptFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !transcriptFilter.isEmpty {
                    Button(action: { transcriptFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            
            let filteredTurns = transcriptFilter.isEmpty ? viewModel.selectedMeetingTranscripts : viewModel.selectedMeetingTranscripts.filter {
                $0.content.localizedCaseInsensitiveContains(transcriptFilter) ||
                $0.speaker.localizedCaseInsensitiveContains(transcriptFilter)
            }
            
            if filteredTurns.isEmpty {
                VStack(spacing: 6) {
                    Text(transcriptFilter.isEmpty ? "No transcript recorded for this meeting." : "No mentions matching \"\(transcriptFilter)\".")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredTurns) { turn in
                        let isInterviewer = turn.speaker.lowercased().contains("interviewer") || turn.speaker.lowercased().contains("them")
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(
                                    turn.speaker,
                                    systemImage: isInterviewer ? "person.crop.circle.badge.questionmark" : "person.crop.circle"
                                )
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isInterviewer ? NativelyTheme.cyanBlue : NativelyTheme.purpleAccent)
                                
                                Spacer()
                                
                                let date = Date(timeIntervalSince1970: Double(turn.timestampMs) / 1000.0)
                                Text(date.formatted(date: .omitted, time: .standard))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(turn.content)
                                .font(.system(size: 12.5))
                                .foregroundColor(.primary)
                                .lineSpacing(2.5)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            isInterviewer ?
                            NativelyTheme.cyanBlue.opacity(0.04) :
                            Color(nsColor: .controlBackgroundColor).opacity(0.6)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 2: AI Solutions
    
    private var interactionsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.selectedMeetingInteractions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No AI solutions requested during this session.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.selectedMeetingInteractions) { interaction in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .foregroundColor(NativelyTheme.purpleAccent)
                                .font(.system(size: 11))
                            Text(interaction.userQuery ?? "AI Question")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Divider()
                            .opacity(0.4)
                        
                        NativeMarkdownView(interaction.aiResponse ?? "")
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nativeCard()
                }
            }
        }
    }
    
    // MARK: - Tab 3: Ask About Meeting (RAG Q&A)
    
    private var askMeetingTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Chat Message Stream
            if viewModel.meetingChatMessages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(NativelyTheme.purpleAccent.opacity(0.6))
                    Text("Ask Anything About This Meeting")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Powered by local Accelerate vector retrieval and SQLite RAG engine. Search specific quotes, questions asked, or commitments made.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.meetingChatMessages) { msg in
                        if msg.role == .user {
                            HStack {
                                Spacer(minLength: 40)
                                Text(msg.text)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(NativelyTheme.purpleAccent)
                                    Text("Meeting Intelligence")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                
                                NativeMarkdownView(msg.text)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .nativeCard()
                        }
                    }
                }
            }
            
            if viewModel.isMeetingChatStreaming {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching meeting notes & transcripts...")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Bottom Input Bar
            HStack(spacing: 8) {
                TextField("Ask anything about this meeting...", text: $chatQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .onSubmit {
                        submitMeetingChat()
                    }
                
                Button(action: submitMeetingChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(chatQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary.opacity(0.4) : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(chatQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Actions
    
    private func submitMeetingChat() {
        let q = chatQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        chatQuery = ""
        viewModel.askAboutSelectedMeeting(question: q)
    }
    
    private func copyMarkdownExport() {
        let md = viewModel.exportMeetingMarkdown(meeting)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCopied = false
        }
    }
    
    private func exportPDF() {
        let md = viewModel.exportMeetingMarkdown(meeting)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(meeting.title ?? "Meeting").pdf"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
                printView.string = md
                let printInfo = NSPrintInfo.shared
                printInfo.topMargin = 36
                printInfo.bottomMargin = 36
                printInfo.leftMargin = 36
                printInfo.rightMargin = 36
                
                let printOp = NSPrintOperation(view: printView, printInfo: printInfo)
                printOp.showsPrintPanel = false
                printOp.showsProgressPanel = false
                
                let pdfData = printView.dataWithPDF(inside: printView.bounds)
                try? pdfData.write(to: url)
            }
        }
    }
    
    private func exportPlainText() {
        let txt = viewModel.exportMeetingPlainText(meeting)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(meeting.title ?? "Meeting").txt"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? txt.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func formatMeetingDate(_ isoString: String?) -> String {
        guard let isoString, let date = ISO8601DateFormatter().date(from: isoString) else {
            return "Recent"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
