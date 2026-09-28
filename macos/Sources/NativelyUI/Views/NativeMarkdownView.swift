import SwiftUI

/// Renders structured Markdown blocks with native typography, syntax highlighting, and LaTeX math.
public struct NativeMarkdownView: View {
    public let markdown: String
    
    public init(_ markdown: String) {
        self.markdown = markdown
    }
    
    public var body: some View {
        let blocks = MarkdownParser.parseBlocks(markdown)
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<blocks.count, id: \.self) { idx in
                renderBlock(blocks[idx])
            }
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(renderInlineSpans(MarkdownParser.parseInline(text)))
                .font(headingFont(for: level))
                .foregroundColor(Color.white.opacity(0.95))
                .padding(.top, level <= 2 ? 6 : 2)
            
        case .paragraph(let text):
            Text(renderInlineSpans(MarkdownParser.parseInline(text)))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.9))
                .lineSpacing(4)
            
        case .codeBlock(let language, let code, let isComplete):
            SyntaxHighlightedCodeBlockView(language: language, code: code, isComplete: isComplete)
                .padding(.vertical, 4)
            
        case .displayMath(let latex):
            LaTeXMathView(latex: latex, isDisplayMode: true)
            
        case .bulletItem(let indent, let text):
            HStack(alignment: .top, spacing: 6) {
                if indent > 0 {
                    Spacer()
                        .frame(width: CGFloat(indent * 12))
                }
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .padding(.top, 6)
                
                Text(renderInlineSpans(MarkdownParser.parseInline(text)))
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.9))
                    .lineSpacing(3)
            }
            
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(minWidth: 18, alignment: .trailing)
                
                Text(renderInlineSpans(MarkdownParser.parseInline(text)))
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.9))
                    .lineSpacing(3)
            }
            
        case .divider:
            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 4)
        }
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 17, weight: .bold)
        case 2:
            return .system(size: 15, weight: .semibold)
        case 3:
            return .system(size: 14, weight: .semibold)
        default:
            return .system(size: 13.5, weight: .medium)
        }
    }
    
    private func renderInlineSpans(_ spans: [InlineSpan]) -> AttributedString {
        var result = AttributedString()
        
        for span in spans {
            switch span {
            case .text(let str):
                var attr = AttributedString(str)
                attr.foregroundColor = Color.white.opacity(0.9)
                result.append(attr)
                
            case .bold(let str):
                var attr = AttributedString(str)
                attr.font = .system(size: 13, weight: .bold)
                attr.foregroundColor = .white
                result.append(attr)
                
            case .italic(let str):
                var attr = AttributedString(str)
                attr.font = .system(size: 13, weight: .regular).italic()
                attr.foregroundColor = Color.white.opacity(0.9)
                result.append(attr)
                
            case .inlineCode(let str):
                var attr = AttributedString(" \(str) ")
                attr.font = .system(size: 12, weight: .medium, design: .monospaced)
                attr.foregroundColor = Color(red: 0.95, green: 0.45, blue: 0.75) // Vibrant inline code
                attr.backgroundColor = Color.white.opacity(0.12)
                result.append(attr)
                
            case .inlineMath(let latex):
                let formatted = LaTeXMathFormatter.formatLaTeX(latex)
                var attr = AttributedString(" \(formatted) ")
                attr.font = .system(size: 13, weight: .regular, design: .serif).italic()
                attr.foregroundColor = Color(red: 0.95, green: 0.85, blue: 0.55) // Warm math amber
                result.append(attr)
                
            case .link(let text, _):
                var attr = AttributedString(text)
                attr.foregroundColor = Color(red: 0.4, green: 0.7, blue: 1.0)
                attr.underlineStyle = .single
                result.append(attr)
            }
        }
        
        return result
    }
}
