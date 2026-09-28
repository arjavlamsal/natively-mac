import SwiftUI
import NativelyCore

/// Sidebar meeting list displaying historical meetings grouped by date with real-time search.
public struct MeetingListView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    
    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.white.opacity(0.4))
                    .font(.system(size: 13))
                TextField("Search meetings & transcripts...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(.white)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.4))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Grouped Meetings List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.groupedMeetings) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                                .padding(.horizontal, 14)
                            
                            ForEach(group.meetings) { meeting in
                                meetingRow(meeting)
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.95))
    }
    
    @ViewBuilder
    private func meetingRow(_ meeting: Meeting) -> some View {
        let isSelected = viewModel.selectedMeeting?.id == meeting.id
        
        Button(action: {
            viewModel.selectMeeting(meeting)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meeting.title ?? "Untitled Meeting")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let durationMs = meeting.durationMs, durationMs > 0 {
                        Text("\(durationMs / 60000)m")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                }
                
                if let summaryJson = meeting.summaryJson, !summaryJson.isEmpty {
                    Text(summaryJson)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color.white.opacity(0.55))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.25) : Color.white.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .contextMenu {
            Button(role: .destructive, action: {
                viewModel.deleteMeeting(meeting)
            }) {
                Label("Delete Meeting", systemImage: "trash")
            }
        }
    }
}
