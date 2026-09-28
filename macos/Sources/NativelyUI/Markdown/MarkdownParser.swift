import Foundation

/// Represents a structural block in parsed Markdown.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String, isComplete: Bool)
    case displayMath(latex: String)
    case bulletItem(indent: Int, text: String)
    case numberedItem(number: Int, text: String)
    case divider
}

/// Represents an inline formatting element within text.
public enum InlineSpan: Equatable, Sendable {
    case text(String)
    case bold(String)
    case italic(String)
    case inlineCode(String)
    case inlineMath(String)
    case link(text: String, url: String)
}

/// Stream-safe Markdown lexer and block parser.
public enum MarkdownParser {
    
    /// Parses raw Markdown text into structured blocks, gracefully handling incomplete streaming blocks.
    public static func parseBlocks(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 1. Check for fenced code block start
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                var isComplete = false
                
                while i < lines.count {
                    let codeLine = lines[i]
                    let codeTrimmed = codeLine.trimmingCharacters(in: .whitespaces)
                    if codeTrimmed.hasPrefix("```") {
                        isComplete = true
                        i += 1
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                
                blocks.append(.codeBlock(
                    language: lang.isEmpty ? "text" : lang.lowercased(),
                    code: codeLines.joined(separator: "\n"),
                    isComplete: isComplete
                ))
                continue
            }
            
            // 2. Check for display math block ($$)
            if trimmed.hasPrefix("$$") {
                var mathLines: [String] = []
                let firstLineRest = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                
                if firstLineRest.hasSuffix("$$") && firstLineRest.count > 2 {
                    // Single line display math: $$ formula $$
                    let formula = String(firstLineRest.dropLast(2)).trimmingCharacters(in: .whitespaces)
                    blocks.append(.displayMath(latex: formula))
                    i += 1
                    continue
                }
                
                if !firstLineRest.isEmpty {
                    mathLines.append(firstLineRest)
                }
                
                i += 1
                while i < lines.count {
                    let mLine = lines[i]
                    let mTrimmed = mLine.trimmingCharacters(in: .whitespaces)
                    if mTrimmed.hasSuffix("$$") {
                        let ending = String(mTrimmed.dropLast(2)).trimmingCharacters(in: .whitespaces)
                        if !ending.isEmpty {
                            mathLines.append(ending)
                        }
                        i += 1
                        break
                    }
                    mathLines.append(mLine)
                    i += 1
                }
                
                blocks.append(.displayMath(latex: mathLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)))
                continue
            }
            
            // 3. Horizontal divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                i += 1
                continue
            }
            
            // 4. Headings (# H1, ## H2, ### H3, #### H4)
            if trimmed.hasPrefix("#") {
                var level = 0
                for char in trimmed {
                    if char == "#" { level += 1 } else { break }
                }
                if level <= 6 && trimmed.count > level && trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " {
                    let headingText = String(trimmed.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
                    blocks.append(.heading(level: level, text: headingText))
                    i += 1
                    continue
                }
            }
            
            // 5. Bullet items (- or *)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                let indent = leadingSpaces / 2
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.bulletItem(indent: indent, text: itemText))
                i += 1
                continue
            }
            
            // 6. Numbered lists (1. , 2. )
            if let match = line.range(of: #"^\s*(\d+)\.\s+(.*)$"#, options: .regularExpression) {
                let matchedString = String(line[match])
                let parts = matchedString.components(separatedBy: ". ")
                if parts.count >= 2, let num = Int(parts[0].trimmingCharacters(in: .whitespaces)) {
                    let itemText = parts.dropFirst().joined(separator: ". ").trimmingCharacters(in: .whitespaces)
                    blocks.append(.numberedItem(number: num, text: itemText))
                    i += 1
                    continue
                }
            }
            
            // 7. Regular paragraph / empty line
            if !trimmed.isEmpty {
                blocks.append(.paragraph(text: trimmed))
            }
            
            i += 1
        }
        
        return blocks
    }
    
    /// Parses inline elements (bold, italic, code, math, links) within a paragraph or list item.
    public static func parseInline(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        var remaining = text[...]
        
        while !remaining.isEmpty {
            // Check for inline math: $formula$
            if remaining.hasPrefix("$") && !remaining.hasPrefix("$$") {
                let afterDollar = remaining.dropFirst()
                if let closingIndex = afterDollar.firstIndex(of: "$") {
                    let mathContent = String(afterDollar[..<closingIndex])
                    if !mathContent.isEmpty && !mathContent.contains("\n") {
                        spans.append(.inlineMath(mathContent))
                        remaining = afterDollar[afterDollar.index(after: closingIndex)...]
                        continue
                    }
                }
            }
            
            // Check for inline code: `code`
            if remaining.hasPrefix("`") {
                let afterTick = remaining.dropFirst()
                if let closingIndex = afterTick.firstIndex(of: "`") {
                    let codeContent = String(afterTick[..<closingIndex])
                    spans.append(.inlineCode(codeContent))
                    remaining = afterTick[afterTick.index(after: closingIndex)...]
                    continue
                }
            }
            
            // Check for bold: **bold**
            if remaining.hasPrefix("**") {
                let afterStar = remaining.dropFirst(2)
                if let closingRange = afterStar.range(of: "**") {
                    let boldContent = String(afterStar[..<closingRange.lowerBound])
                    spans.append(.bold(boldContent))
                    remaining = afterStar[closingRange.upperBound...]
                    continue
                }
            }
            
            // Check for italic: *italic*
            if remaining.hasPrefix("*") {
                let afterStar = remaining.dropFirst()
                if let closingIndex = afterStar.firstIndex(of: "*") {
                    let italicContent = String(afterStar[..<closingIndex])
                    spans.append(.italic(italicContent))
                    remaining = afterStar[afterStar.index(after: closingIndex)...]
                    continue
                }
            }
            
            // Check for link: [text](url)
            if remaining.hasPrefix("[") {
                if let closingBracket = remaining.firstIndex(of: "]"),
                   remaining[closingBracket...].dropFirst().hasPrefix("(") {
                    let textContent = String(remaining[remaining.index(after: remaining.startIndex)..<closingBracket])
                    let afterBracket = remaining[closingBracket...].dropFirst(2)
                    if let closingParen = afterBracket.firstIndex(of: ")") {
                        let urlContent = String(afterBracket[..<closingParen])
                        spans.append(.link(text: textContent, url: urlContent))
                        remaining = afterBracket[afterBracket.index(after: closingParen)...]
                        continue
                    }
                }
            }
            
            // Consume next plain character
            let nextChar = remaining.removeFirst()
            if let last = spans.last, case .text(let prevText) = last {
                spans[spans.count - 1] = .text(prevText + String(nextChar))
            } else {
                spans.append(.text(String(nextChar)))
            }
        }
        
        return spans
    }
}
