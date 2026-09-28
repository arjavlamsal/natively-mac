import SwiftUI

/// Renders mathematical expressions and LaTeX notation with native serif mathematical typography.
public struct LaTeXMathView: View {
    public let latex: String
    public let isDisplayMode: Bool
    
    public init(latex: String, isDisplayMode: Bool = false) {
        self.latex = latex
        self.isDisplayMode = isDisplayMode
    }
    
    public var body: some View {
        let formatted = LaTeXMathFormatter.formatLaTeX(latex)
        
        if isDisplayMode {
            HStack {
                Spacer()
                Text(formatted)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.55)) // Warm Mathematical Amber
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                Spacer()
            }
            .padding(.vertical, 4)
        } else {
            Text(formatted)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.55))
        }
    }
}
