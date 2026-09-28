import SwiftUI
import AppKit

/// Design tokens matching Natively's original high-polish dark aesthetic.
/// Features atmospheric dark surfaces, glowing liquid-glass accents, and Apple-tuned spring physics.
public enum NativelyTheme {
    
    // MARK: - Surfaces & Backgrounds
    
    public static let bgPrimary = Color(red: 0.05, green: 0.05, blue: 0.07)       // #0D0D12
    public static let bgSecondary = Color(red: 0.08, green: 0.08, blue: 0.10)     // #14141A
    public static let bgElevated = Color(red: 0.10, green: 0.10, blue: 0.13)      // #1A1A22
    public static let bgCard = Color(red: 0.12, green: 0.12, blue: 0.15)          // #1E1E26
    public static let bgCardHover = Color(red: 0.15, green: 0.15, blue: 0.19)     // #262630
    
    // MARK: - Borders
    
    public static let borderSubtle = Color.white.opacity(0.07)
    public static let borderMuted = Color.white.opacity(0.12)
    public static let borderHighlight = Color.white.opacity(0.20)
    
    // MARK: - Text
    
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.40)
    public static let tertiaryText = Color.white.opacity(0.40)
    
    // MARK: - Accents & Status
    
    public static let skyAccent = Color(red: 0.05, green: 0.65, blue: 0.95)
    public static let cyanBlue = Color(red: 0.24, green: 0.68, blue: 0.98)
    public static let purpleAccent = Color(red: 0.60, green: 0.40, blue: 0.98)
    public static let emeraldGreen = Color(red: 0.16, green: 0.80, blue: 0.52)
    public static let warningAmber = Color(red: 0.98, green: 0.68, blue: 0.22)
    public static let dangerRed = Color(red: 0.98, green: 0.32, blue: 0.32)
    
    // MARK: - CTA Gradients
    
    public static let ctaIdleGradient = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.72, blue: 0.98),
            Color(red: 0.10, green: 0.55, blue: 0.95),
            Color(red: 0.08, green: 0.38, blue: 0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let ctaActiveGradient = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.85, blue: 0.55),
            Color(red: 0.12, green: 0.72, blue: 0.45),
            Color(red: 0.08, green: 0.58, blue: 0.35)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Animations
    
    public static let appleEase = Animation.timingCurve(0.25, 1, 0.5, 1, duration: 0.32)
    public static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let quickSpring = Animation.spring(response: 0.22, dampingFraction: 0.80)
    
    // MARK: - Visual Effect View
    
    public struct VisualEffectBackground: NSViewRepresentable {
        public let material: NSVisualEffectView.Material
        public let blendingMode: NSVisualEffectView.BlendingMode
        public let state: NSVisualEffectView.State
        
        public init(
            material: NSVisualEffectView.Material = .hudWindow,
            blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
            state: NSVisualEffectView.State = .active
        ) {
            self.material = material
            self.blendingMode = blendingMode
            self.state = state
        }
        
        public func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = state
            return view
        }
        
        public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
            nsView.state = state
        }
    }
}

// MARK: - View Modifiers

public extension View {
    func nativeCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(NativelyTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
    }
    
    func nativeGlassPanel(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NativelyTheme.borderHighlight, lineWidth: 0.5)
            )
    }
}
