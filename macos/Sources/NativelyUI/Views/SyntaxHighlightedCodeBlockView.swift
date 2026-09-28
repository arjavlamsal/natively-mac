import SwiftUI
import AppKit

/// A native syntax-highlighted code block with line numbers and a 1-click Copy button.
public struct SyntaxHighlightedCodeBlockView: View {
    public let language: String
    public let code: String
    public let isComplete: Bool
    
    @State private var isCopied: Bool = false
    
    public init(language: String, code: String, isComplete: Bool = true) {
        self.language = language
        self.code = code
        self.isComplete = isComplete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                Text(language.isEmpty ? "CODE" : language.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                
                if !isComplete {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("generating...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isCopied ? .green : Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Code Body with Line Numbers
            ScrollView(.horizontal, showsIndicators: true) {
                let lines = code.components(separatedBy: "\n")
                HStack(alignment: .top, spacing: 12) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(0..<lines.count, id: \.self) { idx in
                            Text("\(idx + 1)")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.25))
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Code content with syntax tokens
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SyntaxHighlighter.attributedString(for: code, language: language))
                    }
                    .padding(.vertical, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
            }
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
}
