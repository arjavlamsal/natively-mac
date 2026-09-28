import SwiftUI
import AppKit
import NativelyCore

/// Top-level stealth overlay interface adhering to macOS Human Interface Guidelines.
/// Hosts the TopPillBar, Context chips, Rolling Transcript, Conversation stream,
/// persistent Quick Action pills, and the bottom prompt toolbar.
public struct OverlayContentView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    public var onWindowDrag: (CGSize) -> Void = { _ in }
    
    @FocusState private var isInputFocused: Bool
    
    public init(
        viewModel: OverlayViewModel,
        onCropTrigger: @escaping () -> Void = {},
        onWindowDrag: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
        self.onWindowDrag = onWindowDrag
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. TOP CONTROL PILL
            TopPillBarView(viewModel: viewModel, onCropTrigger: onCropTrigger)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { gesture in
                            onWindowDrag(gesture.translation)
                        }
                )
            
            // 2. EXPANDED MEETING INTERFACE
            if viewModel.isExpanded {
                VStack(spacing: 10) {
                    // Context Status Chips (Web DOM, Screen OCR, Screenshots)
                    contextChipsRow
                    
                    // Rolling Transcript Bar
                    if viewModel.showRollingTranscript && (!viewModel.transcripts.isEmpty || viewModel.isAudioActive) {
                        LiveTranscriptView(turns: viewModel.transcripts)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // AI Response Cards & Multi-turn Message Stream
                    AIResponseCardView(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    // Persistent Quick Action Pills Row
                    quickActionButtonsRow
                    
                    // Bottom Input & Controls Toolbar
                    bottomToolbar
                }
                .padding(12)
                .background(
                    NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NativelyTheme.glowStroke, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
            }
        }
        .padding(8)
        .frame(width: 540)
        .animation(NativelyTheme.smoothSpring, value: viewModel.isExpanded)
    }
    
    // MARK: - Context Chips Row
    
    @ViewBuilder
    private var contextChipsRow: some View {
        if viewModel.attachedWebContext != nil || viewModel.attachedOCRSnippet != nil || viewModel.attachedImageBase64 != nil {
            HStack(spacing: 6) {
                // Web Page Context Chip
                if let web = viewModel.attachedWebContext {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 9.5))
                            .foregroundColor(NativelyTheme.cyanBlue)
                        Text("\(web.domain) · \(web.chars) chars")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        
                        Button(action: {
                            viewModel.clearWebContext()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(NativelyTheme.cyanBlue.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(NativelyTheme.cyanBlue.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Screen OCR Chip
                if viewModel.attachedOCRSnippet != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 9.5))
                            .foregroundColor(NativelyTheme.warningAmber)
                        Text("Screen OCR Attached")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Button(action: {
                            viewModel.clearScreenContext()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(NativelyTheme.warningAmber.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(NativelyTheme.warningAmber.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Quick Action Buttons Row
    
    private var quickActionButtonsRow: some View {
        HStack(spacing: 5) {
            actionPill(label: "What to answer?", icon: "pencil", action: {
                viewModel.triggerQuickAction(presetNumber: 1)
            })
            
            actionPill(label: "Clarify", icon: "bubble.left.and.bubble.right", action: {
                viewModel.triggerQuickAction(presetNumber: 2)
            })
            
            actionPill(label: "Recap", icon: "arrow.clockwise", action: {
                viewModel.triggerQuickAction(presetNumber: 3)
            })
            
            actionPill(label: "Follow-up", icon: "questionmark.circle", action: {
                viewModel.triggerQuickAction(presetNumber: 4)
            })
            
            Spacer()
            
            // "Answer" / "Stop" Voice Button
            Button(action: {
                viewModel.toggleManualRecording()
            }) {
                HStack(spacing: 4) {
                    if viewModel.isManualRecording {
                        Circle()
                            .fill(NativelyTheme.dangerRed)
                            .frame(width: 6, height: 6)
                        Text("Stop")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(NativelyTheme.dangerRed)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(NativelyTheme.warningAmber)
                        Text("Answer")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(viewModel.isManualRecording ? NativelyTheme.dangerRed.opacity(0.2) : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(viewModel.isManualRecording ? NativelyTheme.dangerRed.opacity(0.5) : Color.white.opacity(0.14), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Click to manually trigger instant answer or record voice")
        }
        .padding(.horizontal, 2)
    }
    
    private func actionPill(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.75))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        VStack(spacing: 6) {
            // Text Input Box
            HStack(spacing: 8) {
                TextField("Ask anything on screen or conversation, or ⌘⇧X to crop...", text: $viewModel.quickPromptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        submitPrompt()
                    }
                
                // Submit Button
                Button(action: submitPrompt) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.quickPromptText.isEmpty ? .white.opacity(0.2) : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            
            // Bottom Controls Bar (Model Selector, Settings, Crop, Direct Assist)
            HStack(spacing: 8) {
                // Model Selector Button with Popover
                Button(action: {
                    viewModel.isModelSelectorPresented.toggle()
                }) {
                    HStack(spacing: 4) {
                        Text(viewModel.currentModel.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $viewModel.isModelSelectorPresented, arrowEdge: .bottom) {
                    ModelSelectorPopoverView(viewModel: viewModel)
                }
                
                if viewModel.isDirectAssist {
                    Text("DIRECT")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.purpleAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(NativelyTheme.purpleAccent.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                Spacer()
                
                // Screen Crop Button
                Button(action: {
                    onCropTrigger()
                    viewModel.onCropTrigger?()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "crop")
                            .font(.system(size: 10))
                        Text("Crop")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Select area to crop (⌘⇧X)")
                
                // Quick Settings Popover Button
                Button(action: {
                    viewModel.isQuickSettingsPresented.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Quick Settings & Preferences")
                .popover(isPresented: $viewModel.isQuickSettingsPresented, arrowEdge: .bottom) {
                    QuickSettingsPopoverView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private func submitPrompt() {
        let text = viewModel.quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.quickPromptText = ""
        viewModel.askAI(prompt: text)
    }
}
