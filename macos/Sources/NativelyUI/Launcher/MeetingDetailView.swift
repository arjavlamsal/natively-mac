import SwiftUI
import AppKit
import NativelyCore

/// Deep inspection view for a selected meeting displaying summaries, transcripts,
/// AI interactions, and an interactive "Ask About This Meeting" chat powered by local RAG.
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
    
    public init(viewModel: LauncherViewModel, meeting: Meeting) {
        self.viewModel = viewModel
        self.meeting = meeting
        _editableTitle = State(initialValue: meeting.title ?? "Untitled Meeting")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Inline Editable Title
                    HStack(spacing: 8) {
                        if isEditingTitle {
                            TextField("Meeting Title", text: $editableTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: 320)
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
                                .foregroundColor(.white)
                            
                            Button(action: {
                                editableTitle = meeting.title ?? "Untitled Meeting"
                                isEditingTitle = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .help("Rename Meeting")
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(meeting.createdAt ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                        
                        if let duration = meeting.durationMs, duration > 0 {
                            Text("•")
                                .foregroundColor(Color.white.opacity(0.3))
                            Text("\(duration / 60000) mins")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons Toolbar
                HStack(spacing: 8) {
                    // Export Markdown Button
                    Button(action: copyMarkdownExport) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(isCopied ? "Copied" : "Copy Notes")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(isCopied ? .green : Color.white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Export PDF / Print Button
                    Button(action: exportPDF) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 11))
                            Text("Export PDF")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Delete Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(Color.red.opacity(0.8))
                            .padding(6)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete Meeting")
                    .alert("Delete Meeting?", isPresented: $showDeleteConfirmation) {
                        Button("Delete", role: .destructive) {
                            viewModel.deleteMeeting(meeting)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to delete this meeting? All transcripts and summaries will be permanently removed.")
                    }
                }
            }
            .padding(16)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Notes & Summary").tag(0)
                Text("Transcript (\(viewModel.selectedMeetingTranscripts.count))").tag(1)
                Text("AI Solutions (\(viewModel.selectedMeetingInteractions.count))").tag(2)
                Text("Ask About Meeting").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(16)
            }
        }
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
        .onChange(of: meeting.id) { _, _ in
            editableTitle = meeting.title ?? "Untitled Meeting"
            viewModel.meetingChatMessages.removeAll()
        }
    }
    
    // MARK: - Tab 0: Summary
    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let summary = meeting.parsedSummary {
                let actionItems = summary.actionItems ?? []
                let keyPoints = summary.keyPoints ?? []
                
                // Action Items
                if !actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTION ITEMS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.cyan)
                        
                        ForEach(actionItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(Color.cyan)
                                    .font(.system(size: 12))
                                    .padding(.top, 2)
                                Text(item)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cyan.opacity(0.08))
                    .cornerRadius(8)
                }
                
                // Key Points
                if !keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KEY TAKEAWAYS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.purple)
                        
                        ForEach(keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                Text(point)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(8)
                }
            } else if let raw = meeting.summaryJson, !raw.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUMMARY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                    Text(raw)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineSpacing(4)
                }
            } else {
                Text("No summary recorded for this meeting.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Tab 1: Diarized Transcript
    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Transcript Filter Search Box
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.white.opacity(0.4))
                TextField("Search transcript...", text: $transcriptFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                if !transcriptFilter.isEmpty {
                    Button(action: { transcriptFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            let filteredTurns = transcriptFilter.isEmpty ? viewModel.selectedMeetingTranscripts : viewModel.selectedMeetingTranscripts.filter {
                $0.content.localizedCaseInsensitiveContains(transcriptFilter) ||
                $0.speaker.localizedCaseInsensitiveContains(transcriptFilter)
            }
            
            if filteredTurns.isEmpty {
                Text(transcriptFilter.isEmpty ? "No transcript recorded for this session." : "No matches found for \"\(transcriptFilter)\".")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.top, 8)
            } else {
                ForEach(filteredTurns) { turn in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(turn.speaker)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(turn.speaker.lowercased().contains("interviewer") ? Color.cyan : Color.purple)
                            
                            Spacer()
                            
                            let date = Date(timeIntervalSince1970: Double(turn.timestampMs) / 1000.0)
                            Text(date.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        
                        Text(turn.content)
                            .font(.system(size: 12.5))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineSpacing(3)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Tab 2: AI Interactions
    private var interactionsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.selectedMeetingInteractions.isEmpty {
                Text("No AI interactions were triggered during this session.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
            } else {
                ForEach(viewModel.selectedMeetingInteractions) { interaction in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(Color.purple)
                            Text(interaction.userQuery ?? "AI Question")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        NativeMarkdownView(interaction.aiResponse ?? "")
                            .padding(.top, 4)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Tab 3: Ask About Meeting (RAG Q&A)
    private var askMeetingTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASK ABOUT THIS MEETING")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.purple)
            
            // Q&A Conversation
            ForEach(viewModel.meetingChatMessages) { msg in
                if msg.role == .user {
                    HStack {
                        Spacer()
                        Text(msg.text)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(10)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(.purple)
                            Text("Meeting Intelligence")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        NativeMarkdownView(msg.text)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            
            if viewModel.isMeetingChatStreaming {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6).colorInvert()
                    Text("Searching meeting notes & transcripts...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            
            // Input Box
            HStack(spacing: 8) {
                TextField("Ask anything about this meeting...", text: $chatQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onSubmit {
                        submitMeetingChat()
                    }
                
                Button(action: submitMeetingChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(chatQuery.isEmpty ? Color.white.opacity(0.2) : Color.purple)
                }
                .buttonStyle(.plain)
                .disabled(chatQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
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
}
