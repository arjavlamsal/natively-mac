import SwiftUI
import NativelyCore

/// Sidebar meeting list adhering to macOS HIG with native list styling,
/// date-grouped sections, duration badges, and contextual menus.
public struct MeetingListView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    
    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Native macOS Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                
                TextField("Search meetings & notes...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .opacity(0.5)
            
            // Meetings List
            if viewModel.groupedMeetings.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No meetings found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.groupedMeetings) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                // Section Header
                                Text(group.title.uppercased())
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)
                                
                                ForEach(group.meetings) { meeting in
                                    meetingRow(meeting)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }
    
    @ViewBuilder
    private func meetingRow(_ meeting: Meeting) -> some View {
        let isSelected = viewModel.selectedMeeting?.id == meeting.id
        
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                viewModel.selectMeeting(meeting)
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                // Meeting Status Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: meetingIconName(for: meeting))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.75))
                }
                .padding(.top, 1)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(meeting.title ?? "Untitled Meeting")
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let durationMs = meeting.durationMs, durationMs > 0 {
                            Text("\(durationMs / 60000)m")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    
                    if let summaryJson = meeting.summaryJson, !summaryJson.isEmpty {
                        Text(summaryJson)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(2)
                            .lineSpacing(1.5)
                    } else {
                        Text(formatMeetingDate(meeting.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : NativelyTheme.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.exportMeetingMarkdown(meeting), forType: .string)
            }) {
                Label("Copy Notes Markdown", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                withAnimation {
                    viewModel.deleteMeeting(meeting)
                }
            }) {
                Label("Delete Meeting", systemImage: "trash")
            }
        }
    }
    
    private func meetingIconName(for meeting: Meeting) -> String {
        if meeting.summaryStatus == "recording" {
            return "record.circle.fill"
        }
        if meeting.source == "screen" {
            return "display"
        }
        return "waveform"
    }
    
    private func formatMeetingDate(_ isoString: String?) -> String {
        guard let isoString, let date = ISO8601DateFormatter().date(from: isoString) else {
            return "Recent Session"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
