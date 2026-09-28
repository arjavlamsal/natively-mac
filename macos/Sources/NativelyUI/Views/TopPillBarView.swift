import SwiftUI
import NativelyCore

/// Premium liquid glass top control pill adhering to macOS Human Interface Guidelines.
/// Houses the brand mark, show/hide toggle, live dynamic RMS meters, active mode dropdown,
/// stealth status, vision snip trigger, mouse passthrough, model selector, settings, and end-meeting action.
public struct TopPillBarView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    
    public init(viewModel: OverlayViewModel, onCropTrigger: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. BRAND BUTTON (Opens Launcher Dashboard)
            Button(action: {
                viewModel.onOpenLauncher?()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(NativelyTheme.purpleAccent)
                    Text("Natively")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Open Natively Dashboard")
            
            // 2. SHOW / HIDE TOGGLE (⌘B)
            Button(action: {
                withAnimation(NativelyTheme.smoothSpring) {
                    viewModel.isExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(viewModel.isExpanded ? "Hide" : "Show")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Show / Hide Overlay (⌘B)")
            
            Divider()
                .frame(height: 12)
                .opacity(0.3)
            
            // 3. DYNAMIC STEREO AUDIO METERS
            HStack(spacing: 3.5) {
                Circle()
                    .fill(viewModel.isAudioActive ? NativelyTheme.emeraldGreen : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .shadow(color: viewModel.isAudioActive ? NativelyTheme.emeraldGreen.opacity(0.8) : .clear, radius: 4)
                
                // Mic level bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NativelyTheme.emeraldGreen.opacity(0.9))
                    .frame(width: 3, height: max(4, CGFloat(viewModel.micRMS * 16)))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: viewModel.micRMS)
                
                // System audio level bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NativelyTheme.cyanBlue.opacity(0.9))
                    .frame(width: 3, height: max(4, CGFloat(viewModel.systemRMS * 16)))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: viewModel.systemRMS)
            }
            .padding(.horizontal, 4)
            .help("Live Audio: Mic (Green) & System Loopback (Cyan)")
            
            // 4. ACTIVE MODE MENU
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
                        .foregroundColor(.white.opacity(0.9))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            
            // 5. HARDWARE STEALTH BADGE
            HStack(spacing: 3) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 9.5))
                    .foregroundColor(NativelyTheme.emeraldGreen)
                Text("STEALTH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(NativelyTheme.emeraldGreen.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .help("Hardware Stealth: sharingType = .none (Completely invisible to Zoom, Teams, Meet)")
            
            Spacer()
            
            // 6. SCREEN CROP SHORTCUT (⌘⇧X)
            Button(action: {
                onCropTrigger()
                viewModel.onCropTrigger?()
            }) {
                Image(systemName: "crop")
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.attachedOCRSnippet != nil ? NativelyTheme.warningAmber : .white.opacity(0.8))
                    .padding(5.5)
                    .background(viewModel.attachedOCRSnippet != nil ? NativelyTheme.warningAmber.opacity(0.2) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Crop Screen Region & Vision OCR (⌘⇧X)")
            
            // 7. MOUSE PASSTHROUGH TOGGLE (⌘⇧B)
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.isPassthrough.toggle()
                }
            }) {
                Image(systemName: viewModel.isPassthrough ? "hand.point.up.braille" : "cursorarrow.rays")
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.isPassthrough ? NativelyTheme.warningAmber : .white.opacity(0.75))
                    .padding(5.5)
                    .background(viewModel.isPassthrough ? NativelyTheme.warningAmber.opacity(0.2) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle Mouse Passthrough (⌘⇧B)")
            
            // 8. MODEL SELECTOR POPOVER TRIGGER
            Button(action: {
                viewModel.isModelSelectorPresented.toggle()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10.5))
                    Text(viewModel.currentModel.name)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $viewModel.isModelSelectorPresented, arrowEdge: .bottom) {
                ModelSelectorPopoverView(viewModel: viewModel)
            }
            .help("Switch Active AI Model")
            
            // 9. QUICK SETTINGS POPOVER TRIGGER
            Button(action: {
                viewModel.isQuickSettingsPresented.toggle()
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(5.5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $viewModel.isQuickSettingsPresented, arrowEdge: .bottom) {
                QuickSettingsPopoverView(viewModel: viewModel)
            }
            .help("Quick Settings & Shortcuts")
            
            // 10. RED END MEETING BUTTON
            Button(action: {
                viewModel.onEndMeeting?()
            }) {
                ZStack {
                    Circle()
                        .fill(NativelyTheme.dangerRed.opacity(0.2))
                        .frame(width: 22, height: 22)
                    
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(NativelyTheme.dangerRed)
                        .frame(width: 9, height: 9)
                }
            }
            .buttonStyle(.plain)
            .help("Stop & End Session (Save Notes & Summary)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NativelyTheme.glowStroke, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 6)
    }
}
