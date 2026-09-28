import SwiftUI
import NativelyCore

/// Live diarized transcript stream adhering to macOS HIG.
/// Displays microphone ("You") and system audio ("Interviewer") turns with auto-scroll and speaker badges.
public struct LiveTranscriptView: View {
    public let turns: [TranscriptTurn]
    
    public init(turns: [TranscriptTurn]) {
        self.turns = turns
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(NativelyTheme.emeraldGreen)
                        .frame(width: 5, height: 5)
                    Text("LIVE TRANSCRIPTION")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(turns.count) turns")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func turnRow(_ turn: TranscriptTurn) -> some View {
        let isYou = turn.speaker.lowercased() == "you"
        
        HStack(alignment: .top, spacing: 8) {
            // Speaker Badge
            Text(isYou ? "YOU" : "THEM")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isYou ? NativelyTheme.emeraldGreen : NativelyTheme.cyanBlue)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isYou ? NativelyTheme.emeraldGreen.opacity(0.15) : NativelyTheme.cyanBlue.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            // Text Content
            Text(turn.content)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .lineSpacing(1.5)
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}
