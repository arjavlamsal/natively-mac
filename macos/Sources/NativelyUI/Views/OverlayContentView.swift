import SwiftUI
import AppKit
import NativelyCore

/// Top-level stealth overlay interface matching Natively's original layout.
/// Features a dedicated TopPillBar, Context chips, Live Transcripts, AI Response stream,
/// persistent Quick Action pills, and a fully featured bottom toolbar with model selection,
/// settings, crop, and mouse passthrough.
public struct OverlayContentView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    public var onFullScreenCapture: () -> Void = {}
    public var onWindowDrag: (CGSize, Bool) -> Void = { _, _ in }
    
    @FocusState private var isInputFocused: Bool
    
    public init(
        viewModel: OverlayViewModel,
        onCropTrigger: @escaping () -> Void = {},
        onFullScreenCapture: @escaping () -> Void = {},
        onWindowDrag: @escaping (CGSize, Bool) -> Void = { _, _ in }
    ) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
        self.onFullScreenCapture = onFullScreenCapture
        self.onWindowDrag = onWindowDrag
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. TOP CONTROL PILL
            TopPillBarView(
                viewModel: viewModel,
                onCropTrigger: onCropTrigger,
                onFullScreenCapture: onFullScreenCapture,
                onWindowDrag: onWindowDrag
            )
            
            // 2. EXPANDED MEETING INTERFACE
            if viewModel.isExpanded {
                VStack(spacing: 10) {
                    // Context Status Chips (Web DOM, Screen OCR)
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
                .padding(14)
                .background(
                    NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NativelyTheme.borderHighlight, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 510)
        .animation(NativelyTheme.smoothSpring, value: viewModel.isExpanded)
    }
    
    // MARK: - Context Chips Row
    
    @ViewBuilder
    private var contextChipsRow: some View {
        let hasScreen = viewModel.attachedImageBase64 != nil || viewModel.activeScreenContext != nil || viewModel.attachedOCRSnippet != nil
        if viewModel.attachedWebContext != nil || hasScreen {
            HStack(spacing: 8) {
                // Web Page Context Chip
                if let web = viewModel.attachedWebContext {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                            .foregroundColor(NativelyTheme.cyanBlue)
                        Text("\(web.domain) · \(web.chars) chars")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Button(action: {
                            viewModel.clearWebContext()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NativelyTheme.cyanBlue.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(NativelyTheme.cyanBlue.opacity(0.35), lineWidth: 0.5)
                    )
                }
                
                // Screen Screenshot & OCR Chip
                if hasScreen {
                    HStack(spacing: 6) {
                        if let base64 = viewModel.attachedImageBase64 ?? viewModel.activeScreenContext?.base64DataUrl,
                           let img = NSImage(base64Encoding: base64) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(NativelyTheme.warningAmber.opacity(0.4), lineWidth: 0.5)
                                )
                        } else {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(NativelyTheme.warningAmber)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Screen Attached")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let ocr = viewModel.attachedOCRSnippet, !ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("\(ocr.count) chars OCR")
                                    .font(.system(size: 9))
                                    .foregroundColor(NativelyTheme.warningAmber.opacity(0.9))
                                    .lineLimit(1)
                            } else {
                                Text("Vision Ready")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Button(action: {
                            viewModel.clearScreenContext()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 8)
                    .padding(.vertical, 3.5)
                    .background(NativelyTheme.warningAmber.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(NativelyTheme.warningAmber.opacity(0.35), lineWidth: 0.5)
                    )
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Quick Action Buttons Row
    
    private var quickActionButtonsRow: some View {
        HStack(spacing: 6) {
            actionPill(label: "What to answer?", icon: "pencil", shortcut: "⌘1", action: {
                viewModel.triggerQuickAction(presetNumber: 1)
            })
            
            actionPill(label: "Clarify", icon: "bubble.left.and.bubble.right", shortcut: "⌘2", action: {
                viewModel.triggerQuickAction(presetNumber: 2)
            })
            
            actionPill(label: "Recap", icon: "arrow.clockwise", shortcut: "⌘3", action: {
                viewModel.triggerQuickAction(presetNumber: 3)
            })
            
            actionPill(label: "Follow-up", icon: "questionmark.circle", shortcut: "⌘4", action: {
                viewModel.triggerQuickAction(presetNumber: 4)
            })
            
            Spacer()
            
            // "Answer" / "Stop" Voice Recording Button
            Button(action: {
                viewModel.toggleManualRecording()
            }) {
                HStack(spacing: 5) {
                    if viewModel.isManualRecording {
                        Circle()
                            .fill(NativelyTheme.dangerRed)
                            .frame(width: 7, height: 7)
                        Text("Stop")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(NativelyTheme.dangerRed)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(NativelyTheme.warningAmber)
                        Text("Answer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(viewModel.isManualRecording ? NativelyTheme.dangerRed.opacity(0.2) : Color.white.opacity(0.09))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(viewModel.isManualRecording ? NativelyTheme.dangerRed.opacity(0.5) : NativelyTheme.borderMuted, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Click to manually trigger instant answer or record voice")
        }
    }
    
    private func actionPill(label: String, icon: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.8))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        let hasScreen = viewModel.attachedImageBase64 != nil || viewModel.activeScreenContext != nil
        let canSubmit = !viewModel.quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasScreen
        
        return VStack(spacing: 8) {
            // Text Input Field Box
            HStack(spacing: 8) {
                TextField(
                    hasScreen ? "Ask about screenshot (or ↵ to analyze)..." : "Ask anything on screen or conversation (↵ to send)...",
                    text: $viewModel.quickPromptText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onSubmit {
                    submitPrompt()
                }
                
                // Submit Button (Blue Arrow Circle)
                Button(action: submitPrompt) {
                    ZStack {
                        Circle()
                            .fill(canSubmit ? NativelyTheme.skyAccent : Color.white.opacity(0.12))
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(NativelyTheme.bgElevated.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
            )
            
            // Bottom Action Controls (Model Selector, Mode, Crop, Passthrough, Settings)
            HStack(spacing: 8) {
                // 1. Model Selector Dropdown Button
                Button(action: {
                    viewModel.isModelSelectorPresented.toggle()
                }) {
                    HStack(spacing: 5) {
                        Text(viewModel.currentModel.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
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
                        .background(NativelyTheme.purpleAccent.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                
                Divider()
                    .frame(height: 14)
                    .background(NativelyTheme.borderSubtle)
                
                // 2. Active Mode Menu
                Menu {
                    ForEach(viewModel.availableModes) { mode in
                        Button(action: {
                            viewModel.selectMode(mode)
                        }) {
                            HStack {
                                Text(mode.name)
                                if mode.id == viewModel.activeMode.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 10))
                            .foregroundColor(NativelyTheme.cyanBlue)
                        Text(viewModel.activeMode.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                // 3a. Full Screen Capture Button (⌘⇧H)
                Button(action: {
                    onFullScreenCapture()
                    viewModel.onFullScreenCapture?()
                }) {
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                        .foregroundColor(hasScreen ? NativelyTheme.warningAmber : .white.opacity(0.8))
                        .padding(6)
                        .background(hasScreen ? NativelyTheme.warningAmber.opacity(0.2) : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Capture Full Screen & Vision OCR (⌘⇧H)")
                
                // 3b. Screen Crop Button (⌘⇧X)
                Button(action: {
                    onCropTrigger()
                    viewModel.onCropTrigger?()
                }) {
                    Image(systemName: "crop")
                        .font(.system(size: 12))
                        .foregroundColor(hasScreen ? NativelyTheme.warningAmber : .white.opacity(0.8))
                        .padding(6)
                        .background(hasScreen ? NativelyTheme.warningAmber.opacity(0.2) : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Crop Screen Region & Vision OCR (⌘⇧X)")
                
                // 4. Mouse Passthrough Button (⌘⇧B)
                Button(action: {
                    withAnimation(NativelyTheme.quickSpring) {
                        viewModel.isPassthrough.toggle()
                    }
                }) {
                    Image(systemName: viewModel.isPassthrough ? "hand.point.up.braille" : "cursorarrow.rays")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.isPassthrough ? NativelyTheme.warningAmber : .white.opacity(0.8))
                        .padding(6)
                        .background(viewModel.isPassthrough ? NativelyTheme.warningAmber.opacity(0.2) : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Toggle Mouse Passthrough (⌘⇧B)")
                
                // 5. Quick Settings Popover Button
                Button(action: {
                    viewModel.isQuickSettingsPresented.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        var text = viewModel.quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasScreen = viewModel.attachedImageBase64 != nil || viewModel.activeScreenContext != nil
        if text.isEmpty && hasScreen {
            text = "Analyze this screenshot and explain what is shown or what to answer."
        }
        guard !text.isEmpty else { return }
        viewModel.quickPromptText = ""
        viewModel.askAI(prompt: text)
    }
}

