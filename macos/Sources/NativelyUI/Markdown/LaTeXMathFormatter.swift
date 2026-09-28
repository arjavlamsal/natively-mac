import SwiftUI
import Foundation

/// Native LaTeX formula parser and formatter for mathematical expressions and complexity notation.
public enum LaTeXMathFormatter {
    
    private static let symbolReplacements: [(String, String)] = [
        // Greek letters
        (#"\alpha"#, "α"),
        (#"\beta"#, "β"),
        (#"\gamma"#, "γ"),
        (#"\delta"#, "δ"),
        (#"\epsilon"#, "ε"),
        (#"\theta"#, "θ"),
        (#"\lambda"#, "λ"),
        (#"\mu"#, "μ"),
        (#"\pi"#, "π"),
        (#"\sigma"#, "σ"),
        (#"\omega"#, "ω"),
        (#"\Omega"#, "Ω"),
        (#"\Theta"#, "Θ"),
        
        // Relational / logical operators
        (#"\leq"#, "≤"),
        (#"\le"#, "≤"),
        (#"\geq"#, "≥"),
        (#"\ge"#, "≥"),
        (#"\neq"#, "≠"),
        (#"\ne"#, "≠"),
        (#"\approx"#, "≈"),
        (#"\equiv"#, "≡"),
        (#"\times"#, "×"),
        (#"\cdot"#, "·"),
        (#"\pm"#, "±"),
        (#"\in"#, "∈"),
        (#"\notin"#, "∉"),
        (#"\subset"#, "⊂"),
        (#"\subseteq"#, "⊆"),
        (#"\cup"#, "∪"),
        (#"\cap"#, "∩"),
        (#"\to"#, "→"),
        (#"\rightarrow"#, "→"),
        (#"\leftarrow"#, "←"),
        (#"\iff"#, "⟺"),
        (#"\implies"#, "⟹"),
        (#"\forall"#, "∀"),
        (#"\exists"#, "∃"),
        (#"\infty"#, "∞"),
        
        // Big-O and sets
        (#"\mathcal{O}"#, "O"),
        (#"\mathbb{R}"#, "ℝ"),
        (#"\mathbb{Z}"#, "ℤ"),
        (#"\mathbb{N}"#, "ℕ"),
        
        // Calculus / Sums
        (#"\sum"#, "∑"),
        (#"\prod"#, "∏"),
        (#"\int"#, "∫"),
        
        // Spacing
        (#"\quad"#, "  "),
        (#"\qquad"#, "    "),
        (#"\,"#, " "),
        (#"\\"#, "\n")
    ]
    
    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ", "k": "ᵏ", "t": "ᵗ", "x": "ˣ"
    ]
    
    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
        "v": "ᵥ", "x": "ₓ"
    ]

    /// Formats a raw LaTeX mathematical expression into a clean readable Unicode representation.
    public static func formatLaTeX(_ latex: String) -> String {
        var text = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Fractions: \frac{a}{b} -> (a) / (b)
        text = formatFractions(text)
        
        // 2. Square roots: \sqrt{x} -> √(x)
        text = formatSquareRoots(text)
        
        // 3. Known LaTeX macro substitutions
        for (pattern, replacement) in symbolReplacements {
            text = text.replacingOccurrences(of: pattern, with: replacement)
        }
        
        // 4. Superscripts (e.g. x^2 -> x², 2^{n+1} -> 2ⁿ⁺¹)
        text = formatExponents(text)
        
        // 5. Subscripts (e.g. a_i -> aᵢ, x_{min} -> xₘᵢₙ)
        text = formatSubscripts(text)
        
        // 6. Clean up remaining LaTeX artifacts (e.g. \text{...})
        text = text.replacingOccurrences(of: #"\text\{([^}]+)\}"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\mathrm\{([^}]+)\}"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\mathbf\{([^}]+)\}"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\left"#, with: "")
        text = text.replacingOccurrences(of: #"\right"#, with: "")
        
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func formatFractions(_ input: String) -> String {
        var result = input
        let regex = try? NSRegularExpression(pattern: #"\\frac\{([^}]+)\}\{([^}]+)\}"#)
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        
        if let matches = regex?.matches(in: result, range: range) {
            for match in matches.reversed() {
                if let numRange = Range(match.range(at: 1), in: result),
                   let denRange = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {
                    let num = result[numRange]
                    let den = result[denRange]
                    result.replaceSubrange(fullRange, with: "(\(num)) / (\(den))")
                }
            }
        }
        return result
    }

    private static func formatSquareRoots(_ input: String) -> String {
        var result = input
        let regex = try? NSRegularExpression(pattern: #"\\sqrt\{([^}]+)\}"#)
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        
        if let matches = regex?.matches(in: result, range: range) {
            for match in matches.reversed() {
                if let innerRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {
                    let inner = result[innerRange]
                    result.replaceSubrange(fullRange, with: "√(\(inner))")
                }
            }
        }
        return result
    }

    private static func formatExponents(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        
        while i < input.endIndex {
            if input[i] == "^" {
                let nextIdx = input.index(after: i)
                if nextIdx < input.endIndex {
                    if input[nextIdx] == "{" {
                        // Group exponent: ^{...}
                        if let closing = input[nextIdx...].firstIndex(of: "}") {
                            let expContent = input[input.index(after: nextIdx)..<closing]
                            for char in expContent {
                                result.append(superscripts[char] ?? char)
                            }
                            i = input.index(after: closing)
                            continue
                        }
                    } else {
                        // Single char exponent: ^2
                        let char = input[nextIdx]
                        result.append(superscripts[char] ?? char)
                        i = input.index(after: nextIdx)
                        continue
                    }
                }
            }
            result.append(input[i])
            i = input.index(after: i)
        }
        return result
    }

    private static func formatSubscripts(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        
        while i < input.endIndex {
            if input[i] == "_" {
                let nextIdx = input.index(after: i)
                if nextIdx < input.endIndex {
                    if input[nextIdx] == "{" {
                        // Group subscript: _{...}
                        if let closing = input[nextIdx...].firstIndex(of: "}") {
                            let subContent = input[input.index(after: nextIdx)..<closing]
                            for char in subContent {
                                result.append(subscripts[char] ?? char)
                            }
                            i = input.index(after: closing)
                            continue
                        }
                    } else {
                        // Single char subscript: _i
                        let char = input[nextIdx]
                        result.append(subscripts[char] ?? char)
                        i = input.index(after: nextIdx)
                        continue
                    }
                }
            }
            result.append(input[i])
            i = input.index(after: i)
        }
        return result
    }
}
