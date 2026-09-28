import SwiftUI
import AppKit
import NativelyCore

/// Deep inspection view for a selected meeting displaying summaries, transcripts, and AI answers.
public struct MeetingDetailView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    public let meeting: Meeting
    
    @State private var selectedTab: Int = 0
    @State private var isCopied: Bool = false
    
    public init(viewModel: LauncherViewModel, meeting: Meeting) {
        self.viewModel = viewModel
        self.meeting = meeting
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title ?? "Untitled Meeting")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
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
                
                // Export Markdown Button
                Button(action: copyMarkdownExport) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text(isCopied ? "Copied" : "Export")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isCopied ? .green : Color.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Notes & Summary").tag(0)
                Text("Transcript (\(viewModel.selectedMeetingTranscripts.count))").tag(1)
                Text("AI Answers (\(viewModel.selectedMeetingInteractions.count))").tag(2)
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
                    default:
                        EmptyView()
                    }
                }
                .padding(16)
            }
        }
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
    }
    
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
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
    }
    
    private var transcriptTab: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            if viewModel.selectedMeetingTranscripts.isEmpty {
                Text("No transcript turns captured.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
            } else {
                ForEach(viewModel.selectedMeetingTranscripts) { turn in
                    let isYou = turn.speaker.lowercased() == "you"
                    HStack(alignment: .top, spacing: 10) {
                        Text(turn.speaker.uppercased())
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(isYou ? Color(red: 0.4, green: 0.9, blue: 0.6) : Color(red: 0.5, green: 0.7, blue: 1.0))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(isYou ? Color.green.opacity(0.15) : Color.blue.opacity(0.18))
                            .cornerRadius(4)
                        
                        Text(turn.content)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineSpacing(3)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var interactionsTab: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if viewModel.selectedMeetingInteractions.isEmpty {
                Text("No AI assists requested during this meeting.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
            } else {
                ForEach(viewModel.selectedMeetingInteractions) { interaction in
                    VStack(alignment: .leading, spacing: 6) {
                        if let query = interaction.userQuery {
                            HStack {
                                Text("Q:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.purple)
                                Text(query)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        if let resp = interaction.aiResponse {
                            Text(resp)
                                .font(.system(size: 12.5))
                                .foregroundColor(Color.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func copyMarkdownExport() {
        let md = viewModel.exportMeetingMarkdown(meeting)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
}
