import SwiftUI
import AppKit
import NativelyCore

/// Multi-turn conversation view adhering to macOS Human Interface Guidelines.
/// Renders user queries with thumbnail attachments, quick-action chips, and streaming
/// AI cards with native Markdown, syntax-highlighted code blocks, and LaTeX math.
public struct AIResponseCardView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.messages.isEmpty {
                emptyStatePresetView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { msg in
                                if msg.role == .user {
                                    userMessageRow(msg: msg)
                                } else {
                                    assistantMessageCard(msg: msg)
                                }
                            }
                            
                            // Animated thinking indicator
                            if viewModel.isAIStreaming && (viewModel.messages.last?.text.isEmpty ?? true) {
                                thinkingIndicator
                            }
                            
                            Color.clear
                                .frame(height: 1)
                                .id("bottom-anchor")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(NativelyTheme.smoothSpring) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.currentAIText) { _, _ in
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - User Message Row
    
    private func userMessageRow(msg: OverlayMessage) -> some View {
        HStack {
            Spacer(minLength: 40)
            
            VStack(alignment: .trailing, spacing: 4) {
                // Screenshot thumbnail preview if present
                if let preview = msg.screenshotPreview, let img = NSImage(base64Encoding: preview) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                
                HStack(spacing: 5) {
                    if msg.isQuickActionLabel {
                        Image(systemName: quickActionIcon(for: msg.actionKind))
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Text(msg.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [NativelyTheme.purpleAccent, NativelyTheme.purpleAccent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: NativelyTheme.purpleAccent.opacity(0.3), radius: 6, y: 2)
            }
        }
    }
    
    // MARK: - Assistant Message Card
    
    private func assistantMessageCard(msg: OverlayMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Bar
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(NativelyTheme.purpleAccent)
                
                Text(msg.modelName ?? viewModel.currentProviderName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                if let latency = msg.latencyMs {
                    Text("⚡ \(Int(latency))ms TTFT")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.emeraldGreen)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(NativelyTheme.emeraldGreen.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                
                if msg.isStreaming {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(NativelyTheme.purpleAccent)
                            .frame(width: 4.5, height: 4.5)
                        Text("Streaming")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(NativelyTheme.purpleAccent)
                    }
                }
                
                Spacer()
                
                // Copy Answer Button
                CopyAnswerButton(textToCopy: msg.text)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            Divider()
                .opacity(0.2)
            
            // Markdown / Code Content
            if !msg.text.isEmpty {
                NativeMarkdownView(msg.text)
                    .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }
    
    // MARK: - Thinking Indicator
    
    private var thinkingIndicator: some View {
        HStack(spacing: 7) {
            ProgressView()
                .scaleEffect(0.6)
                .colorInvert()
            Text("Thinking...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
    
    // MARK: - Empty State View
    
    private var emptyStatePresetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED ACTIONS")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .padding(.horizontal, 4)
            
            HStack(spacing: 6) {
                presetPill(label: "What to Answer", icon: "pencil", shortcut: "⌘1", actionIndex: 1)
                presetPill(label: "Clarify", icon: "bubble.left.and.bubble.right", shortcut: "⌘2", actionIndex: 2)
                presetPill(label: "Recap", icon: "arrow.clockwise", shortcut: "⌘3", actionIndex: 3)
            }
            
            HStack(spacing: 6) {
                presetPill(label: "Follow-up", icon: "questionmark.circle", shortcut: "⌘4", actionIndex: 4)
                presetPill(label: "Code Hint", icon: "chevron.left.forwardslash.chevron.right", shortcut: "⌘6", actionIndex: 6)
                presetPill(label: "Full Solution", icon: "checkmark.seal", shortcut: "⌘5", actionIndex: 5)
            }
        }
        .padding(6)
    }
    
    private func presetPill(label: String, icon: String, shortcut: String, actionIndex: Int) -> some View {
        Button(action: {
            viewModel.triggerQuickAction(presetNumber: actionIndex)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                Text(shortcut)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func quickActionIcon(for kind: String?) -> String {
        switch kind {
        case "what_to_say": return "pencil"
        case "clarify": return "bubble.left.and.bubble.right"
        case "recap": return "arrow.clockwise"
        case "follow_up_questions": return "questionmark.circle"
        case "code_hint": return "chevron.left.forwardslash.chevron.right"
        case "full_solution": return "checkmark.seal"
        default: return "sparkles"
        }
    }
}

/// Helper button for copying the complete answer text with feedback.
private struct CopyAnswerButton: View {
    let textToCopy: String
    @State private var isCopied: Bool = false
    
    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isCopied = false
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                Text(isCopied ? "Copied" : "Copy")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(isCopied ? NativelyTheme.emeraldGreen : .white.opacity(0.6))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isCopied ? NativelyTheme.emeraldGreen.opacity(0.14) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Copy full answer")
    }
}

private extension NSImage {
    convenience init?(base64Encoding: String) {
        guard let data = Data(base64Encoded: base64Encoding) else { return nil }
        self.init(data: data)
    }
}
