import SwiftUI
import NativelyCore

/// Sleek liquid glass top control pill displaying status indicators, audio meters, mode selector, and quick triggers.
public struct TopPillBarView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    
    public init(viewModel: OverlayViewModel, onCropTrigger: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Drag Grip Indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.35))
                .help("Drag to reposition overlay")
            
            // Audio Engine Activity Pulse
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isAudioActive ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .shadow(color: viewModel.isAudioActive ? Color.green.opacity(0.8) : .clear, radius: 4)
                
                // Mic RMS level mini-bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 3, height: max(4, CGFloat(viewModel.micRMS * 14)))
                
                // System audio RMS level mini-bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.cyan.opacity(0.8))
                    .frame(width: 3, height: max(4, CGFloat(viewModel.systemRMS * 14)))
            }
            .help("Audio Engine: Mic (Green) & System Loopback (Cyan)")
            
            Divider()
                .frame(height: 12)
                .background(Color.white.opacity(0.15))
            
            // Mode Selector Pill
            Menu {
                ForEach(viewModel.availableModes) { mode in
                    Button(action: {
                        viewModel.activeMode = mode
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
                        .font(.system(size: 11))
                        .foregroundColor(Color.cyan)
                    Text(viewModel.activeMode.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.9))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
            }
            .menuStyle(.borderlessButton)
            
            // Hardware Stealth Shield
            HStack(spacing: 3) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.4, green: 0.9, blue: 0.6))
                Text("STEALTH")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color(red: 0.1, green: 0.3, blue: 0.2).opacity(0.4))
            .cornerRadius(4)
            .help("Hardware Stealth: sharingType = .none (Completely invisible to Zoom, Teams, Meet, ScreenCaptureKit)")
            
            Spacer()
            
            // Screen Crop Shortcut Button (Cmd+Shift+X)
            Button(action: onCropTrigger) {
                HStack(spacing: 4) {
                    Image(systemName: "crop")
                        .font(.system(size: 11))
                    Text("Crop")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(viewModel.attachedOCRSnippet != nil ? Color.yellow : Color.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(viewModel.attachedOCRSnippet != nil ? Color.yellow.opacity(0.15) : Color.white.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Crop Screen Region & OCR (⌘⇧X)")
            
            // Mouse Passthrough Toggle (Cmd+Shift+B)
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
            
            // Expand / Collapse Chevron
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isExpanded.toggle()
                }
            }) {
                Image(systemName: viewModel.isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Expand / Collapse Overlay (⌘B)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.88))
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 3)
    }
}
