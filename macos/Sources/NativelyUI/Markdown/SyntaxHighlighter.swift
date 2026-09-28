import SwiftUI
import Foundation

/// Syntax highlight categories.
public enum SyntaxCategory: Equatable, Sendable {
    case keyword
    case type
    case string
    case comment
    case number
    case plain
    
    public var color: Color {
        switch self {
        case .keyword:
            return Color(red: 0.95, green: 0.38, blue: 0.68) // Vibrant Pink / Magenta
        case .type:
            return Color(red: 0.35, green: 0.82, blue: 0.95) // Cyan
        case .string:
            return Color(red: 0.48, green: 0.86, blue: 0.58) // Soft Emerald
        case .comment:
            return Color(red: 0.55, green: 0.60, blue: 0.68) // Slate Gray
        case .number:
            return Color(red: 1.00, green: 0.70, blue: 0.38) // Amber Orange
        case .plain:
            return Color(red: 0.92, green: 0.94, blue: 0.97) // Pure Text
        }
    }
}

/// Tokenized code segment with text and syntax category.
public struct HighlightedToken: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let text: String
    public let category: SyntaxCategory
    
    public init(text: String, category: SyntaxCategory) {
        self.text = text
        self.category = category
    }
}

/// Fast native syntax highlighter without WebViews or external node dependencies.
public enum SyntaxHighlighter {
    
    private static let keywords: Set<String> = [
        // Swift / Rust / Go / JS / TS / Python / C++
        "func", "def", "fn", "function", "class", "struct", "enum", "protocol", "interface",
        "type", "impl", "trait", "import", "from", "export", "package", "let", "var", "const",
        "val", "mut", "if", "else", "elif", "switch", "case", "match", "default", "for", "while",
        "in", "of", "return", "break", "continue", "yield", "await", "async", "try", "catch",
        "throw", "throws", "defer", "guard", "self", "this", "super", "nil", "null", "None",
        "true", "false", "True", "False", "public", "private", "fileprivate", "internal",
        "override", "static", "select", "from", "where", "join", "insert", "update", "delete"
    ]
    
    private static let types: Set<String> = [
        "Int", "Int32", "Int64", "UInt", "Float", "Double", "String", "Bool", "Character",
        "Array", "Dictionary", "Set", "Optional", "Result", "Error", "Any", "Sendable",
        "Task", "Actor", "MainActor", "View", "Text", "Color", "str", "int", "float", "bool",
        "list", "dict", "tuple", "set", "number", "boolean", "any", "void", "never", "unknown"
    ]

    /// Highlights code and returns an array of lines, each line containing tokenized segments.
    public static func highlight(code: String, language: String = "") -> [[HighlightedToken]] {
        let lines = code.components(separatedBy: "\n")
        return lines.map { highlightLine($0, language: language.lowercased()) }
    }
    
    /// Generates a SwiftUI AttributedString with full syntax highlighting.
    public static func attributedString(for code: String, language: String = "") -> AttributedString {
        var result = AttributedString()
        let lines = highlight(code: code, language: language)
        
        for (lineIdx, lineTokens) in lines.enumerated() {
            for token in lineTokens {
                var attrToken = AttributedString(token.text)
                attrToken.foregroundColor = token.category.color
                attrToken.font = .system(size: 12.5, weight: .regular, design: .monospaced)
                result.append(attrToken)
            }
            if lineIdx < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }

    private static func highlightLine(_ line: String, language: String) -> [HighlightedToken] {
        var tokens: [HighlightedToken] = []
        var cursor = line.startIndex
        
        while cursor < line.endIndex {
            let remaining = line[cursor...]
            
            // 1. Comments
            if remaining.hasPrefix("//") || (language == "python" || language == "bash" || language == "sh") && remaining.hasPrefix("#") {
                tokens.append(HighlightedToken(text: String(remaining), category: .comment))
                break
            }
            
            // 2. String literals ("..." or '...' or `...`)
            let firstChar = remaining.first!
            if firstChar == "\"" || firstChar == "'" || firstChar == "`" {
                var endCursor = line.index(after: cursor)
                var escaped = false
                while endCursor < line.endIndex {
                    let char = line[endCursor]
                    if escaped {
                        escaped = false
                    } else if char == "\\" {
                        escaped = true
                    } else if char == firstChar {
                        endCursor = line.index(after: endCursor)
                        break
                    }
                    endCursor = line.index(after: endCursor)
                }
                let str = String(line[cursor..<endCursor])
                tokens.append(HighlightedToken(text: str, category: .string))
                cursor = endCursor
                continue
            }
            
            // 3. Numbers
            if firstChar.isNumber {
                var endCursor = cursor
                while endCursor < line.endIndex && (line[endCursor].isNumber || line[endCursor] == "." || line[endCursor] == "x" || line[endCursor].isHexDigit) {
                    endCursor = line.index(after: endCursor)
                }
                let numStr = String(line[cursor..<endCursor])
                tokens.append(HighlightedToken(text: numStr, category: .number))
                cursor = endCursor
                continue
            }
            
            // 4. Identifiers / Keywords / Types
            if firstChar.isLetter || firstChar == "_" {
                var endCursor = cursor
                while endCursor < line.endIndex && (line[endCursor].isLetter || line[endCursor].isNumber || line[endCursor] == "_") {
                    endCursor = line.index(after: endCursor)
                }
                let word = String(line[cursor..<endCursor])
                if keywords.contains(word) {
                    tokens.append(HighlightedToken(text: word, category: .keyword))
                } else if types.contains(word) || (word.first?.isUppercase == true && word.count > 1) {
                    tokens.append(HighlightedToken(text: word, category: .type))
                } else {
                    tokens.append(HighlightedToken(text: word, category: .plain))
                }
                cursor = endCursor
                continue
            }
            
            // 5. Plain / whitespace / symbols
            var endCursor = cursor
            while endCursor < line.endIndex {
                let c = line[endCursor]
                if c.isLetter || c.isNumber || c == "_" || c == "\"" || c == "'" || c == "`" || (c == "/" && line[endCursor...].hasPrefix("//")) || (c == "#" && (language == "python" || language == "bash")) {
                    break
                }
                endCursor = line.index(after: endCursor)
            }
            let plainText = String(line[cursor..<endCursor])
            tokens.append(HighlightedToken(text: plainText, category: .plain))
            cursor = endCursor
        }
        
        return tokens
    }
}
