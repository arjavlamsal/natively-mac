import SwiftUI
import AppKit

/// Unified macOS Human Interface Guidelines (HIG) theme tokens for Natively.
/// Provides system materials, semantic colors, smooth continuous shapes, and fluid spring animations.
public enum NativelyTheme {
    
    // MARK: - Semantic Colors
    
    public static let accent = Color(nsColor: .controlAccentColor)
    public static let purpleAccent = Color(red: 0.58, green: 0.38, blue: 0.98)
    public static let emeraldGreen = Color(red: 0.20, green: 0.82, blue: 0.55)
    public static let warningAmber = Color(red: 0.98, green: 0.65, blue: 0.22)
    public static let dangerRed = Color(red: 0.98, green: 0.33, blue: 0.33)
    public static let cyanBlue = Color(red: 0.24, green: 0.68, blue: 0.98)
    
    // Backgrounds & Surfaces
    public static let windowBackground = Color(nsColor: .windowBackgroundColor)
    public static let controlBackground = Color(nsColor: .controlBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .underPageBackgroundColor)
    
    // Text
    public static let primaryText = Color(nsColor: .labelColor)
    public static let secondaryText = Color(nsColor: .secondaryLabelColor)
    public static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    
    // MARK: - Border & Stroke
    
    public static let subtleBorder = Color(nsColor: .separatorColor).opacity(0.5)
    public static let cardBorder = Color.white.opacity(0.12)
    public static let glowStroke = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Shapes & Radii
    
    public static let pillCornerRadius: CGFloat = 20
    public static let cardCornerRadius: CGFloat = 12
    public static let panelCornerRadius: CGFloat = 16
    
    public static let squirclePanel = RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
    public static let squircleCard = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    public static let squirclePill = RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
    
    // MARK: - Animations
    
    public static let smoothSpring = Animation.spring(response: 0.32, dampingFraction: 0.84)
    public static let quickSpring = Animation.spring(response: 0.22, dampingFraction: 0.78)
    public static let bounceSpring = Animation.spring(response: 0.40, dampingFraction: 0.65)
    
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

// MARK: - View Modifiers for Native macOS Styling

public extension View {
    /// Applies a frosted glass HUD styling with continuous corners and subtle border stroke.
    func nativeGlassPanel(cornerRadius: CGFloat = NativelyTheme.panelCornerRadius) -> some View {
        self
            .background(
                NativelyTheme.VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NativelyTheme.glowStroke, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 8)
    }
    
    /// Applies a clean card container style adhering to macOS HIG.
    func nativeCard(cornerRadius: CGFloat = NativelyTheme.cardCornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
    }
}
