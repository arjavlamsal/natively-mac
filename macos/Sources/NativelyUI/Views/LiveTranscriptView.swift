import SwiftUI
import NativelyCore

/// Live diarized transcript stream displaying microphone ("You") and system audio ("Interviewer") turns.
public struct LiveTranscriptView: View {
    public let turns: [TranscriptTurn]
    
    public init(turns: [TranscriptTurn]) {
        self.turns = turns
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LIVE TRANSCRIPTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                Spacer()
                Text("\(turns.count) turns")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(turns.suffix(15).enumerated()), id: \.element.timestampMs) { _, turn in
                            turnRow(turn)
                                .id(turn.timestampMs)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 130)
                .onChange(of: turns.count) { _, _ in
                    if let lastTimestamp = turns.last?.timestampMs {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastTimestamp, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func turnRow(_ turn: TranscriptTurn) -> some View {
        let isYou = turn.speaker.lowercased() == "you"
        
        HStack(alignment: .top, spacing: 8) {
            // Speaker Badge
            Text(isYou ? "YOU" : "THEM")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isYou ? Color(red: 0.4, green: 0.9, blue: 0.6) : Color(red: 0.5, green: 0.7, blue: 1.0))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isYou ? Color.green.opacity(0.15) : Color.blue.opacity(0.18))
                .cornerRadius(4)
            
            // Text Content
            Text(turn.content)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.85))
                .lineLimit(3)
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
