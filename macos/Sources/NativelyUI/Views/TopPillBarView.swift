import SwiftUI
import NativelyCore

/// Sleek liquid glass top control pill matching Natively's floating top bar.
/// Houses the brand mark, show/hide toggle, live audio meters, active mode dropdown,
/// stealth status, crop trigger, and the red stop/end-meeting button.
public struct TopPillBarView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    
    public init(viewModel: OverlayViewModel, onCropTrigger: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. BRAND LOGO BUTTON (Opens Launcher)
            Button(action: {
                viewModel.onOpenLauncher?()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Natively")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help("Open Natively Dashboard")
            
            // 2. SHOW / HIDE TOGGLE (Cmd+B)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    viewModel.isExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(viewModel.isExpanded ? "Hide" : "Show")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.9))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Show / Hide Overlay (⌘B)")
            
            Divider()
                .frame(height: 12)
                .background(Color.white.opacity(0.15))
            
            // 3. AUDIO ENGINE ACTIVITY METERS
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isAudioActive ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .shadow(color: viewModel.isAudioActive ? Color.green.opacity(0.8) : .clear, radius: 4)
                
                // Mic RMS level mini-bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 2.5, height: max(4, CGFloat(viewModel.micRMS * 14)))
                
                // System audio RMS level mini-bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.cyan.opacity(0.85))
                    .frame(width: 2.5, height: max(4, CGFloat(viewModel.systemRMS * 14)))
            }
            .help("Audio Engine: Mic (Green) & System Loopback (Cyan)")
            
            // 4. ACTIVE MODE DROPDOWN PILL
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
                        .foregroundColor(Color.cyan)
                    Text(viewModel.activeMode.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.9))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            .menuStyle(.borderlessButton)
            
            // 5. HARDWARE STEALTH SHIELD
            HStack(spacing: 3) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                Text("STEALTH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color(red: 0.1, green: 0.3, blue: 0.2).opacity(0.4))
            .cornerRadius(4)
            .help("Hardware Stealth: sharingType = .none (Completely invisible to Zoom, Teams, Meet)")
            
            Spacer()
            
            // 6. SCREEN CROP SHORTCUT (Cmd+Shift+X)
            Button(action: {
                onCropTrigger()
                viewModel.onCropTrigger?()
            }) {
                Image(systemName: "crop")
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.attachedOCRSnippet != nil ? Color.yellow : Color.white.opacity(0.75))
                    .padding(5)
                    .background(viewModel.attachedOCRSnippet != nil ? Color.yellow.opacity(0.18) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Crop Screen Region & OCR (⌘⇧X)")
            
            // 7. MOUSE PASSTHROUGH TOGGLE (Cmd+Shift+B)
            Button(action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.isPassthrough.toggle()
                }
            }) {
                Image(systemName: viewModel.isPassthrough ? "hand.point.up.braille" : "cursorarrow.rays")
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.isPassthrough ? Color.orange : Color.white.opacity(0.7))
                    .padding(5)
                    .background(viewModel.isPassthrough ? Color.orange.opacity(0.2) : Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle Mouse Passthrough (⌘⇧B)")
            
            // 8. END MEETING / STOP BUTTON
            Button(action: {
                viewModel.onEndMeeting?()
            }) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 10, height: 10)
                    .padding(6)
                    .background(Color.red.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Stop & End Session (Save Notes & Summary)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.92))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
    }
}
