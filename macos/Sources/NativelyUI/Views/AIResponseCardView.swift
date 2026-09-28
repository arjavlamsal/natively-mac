import SwiftUI
import AppKit
import NativelyCore

/// Multi-turn conversation view rendering user queries, quick-action chips,
/// attached screenshot thumbnails, and streaming AI assistant cards with Markdown,
/// syntax-highlighted code blocks, and LaTeX math.
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
                            
                            // Shimmering "Thinking..." indicator
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
                        withAnimation {
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
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                // If screenshot attached, display thumbnail preview
                if let preview = msg.screenshotPreview, let img = NSImage(base64Encoding: preview) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 60)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                HStack(spacing: 5) {
                    if msg.isQuickActionLabel {
                        Image(systemName: quickActionIcon(for: msg.actionKind))
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                    }
                    
                    Text(msg.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.25))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                )
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
                    .foregroundColor(.purple)
                
                Text(msg.modelName ?? viewModel.currentProviderName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.85))
                
                if let latency = msg.latencyMs {
                    Text("⚡ \(Int(latency))ms TTFT")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(3)
                }
                
                if msg.isStreaming {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 4, height: 4)
                        Text("Streaming")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
                
                // Copy Answer Button
                CopyAnswerButton(textToCopy: msg.text)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            Divider().background(Color.white.opacity(0.08))
            
            // Markdown Content
            if !msg.text.isEmpty {
                NativeMarkdownView(msg.text)
                    .padding(.vertical, 2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Thinking Shimmer Indicator
    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
                .colorInvert()
            Text("Thinking...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Empty State View
    private var emptyStatePresetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED ACTIONS")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
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
                    .foregroundColor(Color.white.opacity(0.5))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(3)
            }
            .foregroundColor(Color.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
            .foregroundColor(isCopied ? Color.green : Color.white.opacity(0.55))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isCopied ? Color.green.opacity(0.12) : Color.white.opacity(0.06))
            .cornerRadius(4)
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
