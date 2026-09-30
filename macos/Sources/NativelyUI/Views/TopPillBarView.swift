import SwiftUI
import NativelyCore

/// Clean, spacious, and uncluttered top control pill matching Natively's original design.
/// Only contains window and session essentials: Brand Mark, Hide/Show toggle, Live Audio meters,
/// Stealth status, and End Meeting button. Model and settings controls are neatly grouped in the bottom bar.
public struct TopPillBarView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    public var onWindowDrag: (CGSize, Bool) -> Void = { _, _ in }
    
    public init(
        viewModel: OverlayViewModel,
        onCropTrigger: @escaping () -> Void = {},
        onWindowDrag: @escaping (CGSize, Bool) -> Void = { _, _ in }
    ) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
        self.onWindowDrag = onWindowDrag
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Drag Grip Handle (Dedicated drag region to prevent child button interference)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(NativelyTheme.textTertiary.opacity(0.8))
                .frame(width: 12, height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { gesture in
                            onWindowDrag(gesture.translation, false)
                        }
                        .onEnded { gesture in
                            onWindowDrag(gesture.translation, true)
                        }
                )
                .help("Drag to reposition overlay")
            
            // 1. BRAND LOGO BUTTON (Opens Launcher Dashboard)
            Button(action: {
                viewModel.onOpenLauncher?()
            }) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(NativelyTheme.purpleAccent.opacity(0.25))
                            .frame(width: 22, height: 22)
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(NativelyTheme.purpleAccent)
                    }
                    
                    Text("Natively")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NativelyTheme.textPrimary)
                }
                .padding(.leading, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Natively Dashboard")
            
            Divider()
                .frame(height: 14)
                .background(NativelyTheme.borderSubtle)
            
            // 2. SHOW / HIDE TOGGLE (⌘B)
            Button(action: {
                withAnimation(NativelyTheme.smoothSpring) {
                    viewModel.isExpanded.toggle()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(viewModel.isExpanded ? "Hide" : "Show")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(NativelyTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Show / Hide Overlay (⌘B)")
            
            // 3. DYNAMIC STEREO AUDIO METERS
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isAudioActive ? NativelyTheme.emeraldGreen : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
                    .shadow(color: viewModel.isAudioActive ? NativelyTheme.emeraldGreen.opacity(0.8) : .clear, radius: 4)
                
                // Mic RMS meter bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NativelyTheme.emeraldGreen)
                    .frame(width: 3, height: max(5, CGFloat(viewModel.micRMS * 18)))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: viewModel.micRMS)
                
                // System loopback RMS meter bar
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(NativelyTheme.cyanBlue)
                    .frame(width: 3, height: max(5, CGFloat(viewModel.systemRMS * 18)))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: viewModel.systemRMS)
            }
            .padding(.horizontal, 4)
            .help("Live Audio: Mic (Green) & System Loopback (Cyan)")
            
            // 4. HARDWARE STEALTH BADGE
            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(NativelyTheme.emeraldGreen)
                Text("STEALTH")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.emeraldGreen)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(NativelyTheme.emeraldGreen.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .help("Hardware Stealth: sharingType = .none (Completely invisible to Zoom, Teams, Meet)")
            
            Spacer()
            
            // 5. RED END MEETING / STOP BUTTON
            Button(action: {
                viewModel.onEndMeeting?()
            }) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(NativelyTheme.dangerRed)
                        .frame(width: 9, height: 9)
                    
                    Text("Stop")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(NativelyTheme.dangerRed)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(NativelyTheme.dangerRed.opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(NativelyTheme.dangerRed.opacity(0.35), lineWidth: 0.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Stop & End Session (Save Notes & Summary)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(NativelyTheme.borderHighlight, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 6)
    }
}
