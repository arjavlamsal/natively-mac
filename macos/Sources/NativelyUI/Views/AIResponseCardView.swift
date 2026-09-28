import SwiftUI

/// Streaming AI response card rendering live Markdown, code, LaTeX math, and quick preset buttons.
public struct AIResponseCardView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    
    @FocusState private var isInputFocused: Bool
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text(viewModel.currentProviderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.9))
                }
                
                if let latency = viewModel.ttftLatencyMs {
                    Text("⚡ \(Int(latency))ms TTFT")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                }
                
                if viewModel.isAIStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 5, height: 5)
                        Text("Streaming")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
                
                if viewModel.attachedOCRSnippet != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 10))
                        Text("Screen OCR Active")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(4)
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.clearSession()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear Session")
            }
            .padding(.horizontal, 4)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content Area
            if viewModel.currentAIText.isEmpty && !viewModel.isAIStreaming {
                quickPresetsView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            NativeMarkdownView(viewModel.currentAIText)
                                .id("stream-bottom")
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 260)
                    .onChange(of: viewModel.currentAIText) { _, _ in
                        proxy.scrollTo("stream-bottom", anchor: .bottom)
                    }
                }
            }
            
            // Quick Input / Follow-up Bar
            HStack(spacing: 8) {
                TextField("Ask follow-up or press ⌘1-7...", text: $viewModel.quickPromptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitPrompt()
                    }
                
                Button(action: submitPrompt) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.quickPromptText.isEmpty ? Color.white.opacity(0.3) : Color.purple)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.quickPromptText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onChange(of: viewModel.isFocusingPrompt) { _, focusing in
                if focusing {
                    isInputFocused = true
                    viewModel.isFocusingPrompt = false
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var quickPresetsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED ACTIONS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
            
            HStack(spacing: 6) {
                presetPill(label: "What to Answer", shortcut: "⌘1", actionIndex: 1)
                presetPill(label: "Clarify", shortcut: "⌘2", actionIndex: 2)
                presetPill(label: "Recap", shortcut: "⌘3", actionIndex: 3)
            }
            
            HStack(spacing: 6) {
                presetPill(label: "Code Hint", shortcut: "⌘6", actionIndex: 6)
                presetPill(label: "Full Solution", shortcut: "⌘5", actionIndex: 5)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func presetPill(label: String, shortcut: String, actionIndex: Int) -> some View {
        Button(action: {
            viewModel.triggerQuickAction(presetNumber: actionIndex)
        }) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.9))
                Text(shortcut)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.purple.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.18))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func submitPrompt() {
        let text = viewModel.quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.quickPromptText = ""
        viewModel.askAI(prompt: text)
    }
}
