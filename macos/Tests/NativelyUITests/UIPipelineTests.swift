import Testing
import Foundation
import AppKit
@testable import NativelyCore
@testable import NativelyDatabase
@testable import NativelyAudio
@testable import NativelyUI

@Suite("NativelyUI Pipeline Tests")
struct UIPipelineTests {
    
    @Test("MarkdownParser correctly decomposes blocks including streaming code fences")
    func testMarkdownParserBlocks() {
        let sampleMarkdown = """
        # High Level Overview
        This is an introductory paragraph explaining the algorithm.
        
        ## Complexity Analysis
        - Time: $O(N \\log N)$
        - Space: $O(1)$
        
        $$
        T(N) = 2T(N/2) + O(N)
        $$
        
        ```python
        def merge_sort(arr):
            if len(arr) <= 1:
                return arr
        ```
        
        ---
        1. Step one
        2. Step two
        """
        
        let blocks = MarkdownParser.parseBlocks(sampleMarkdown)
        
        #expect(blocks.contains { block in
            if case .heading(let level, let text) = block {
                return level == 1 && text == "High Level Overview"
            }
            return false
        })
        
        #expect(blocks.contains { block in
            if case .bulletItem(_, let text) = block {
                return text.contains("Time:")
            }
            return false
        })
        
        #expect(blocks.contains { block in
            if case .displayMath(let latex) = block {
                return latex.contains("T(N) = 2T(N/2)")
            }
            return false
        })
        
        #expect(blocks.contains { block in
            if case .codeBlock(let lang, let code, let isComplete) = block {
                return lang == "python" && code.contains("def merge_sort") && isComplete
            }
            return false
        })
        
        #expect(blocks.contains { block in
            if case .divider = block { return true }
            return false
        })
        
        #expect(blocks.contains { block in
            if case .numberedItem(let num, let text) = block {
                return num == 1 && text == "Step one"
            }
            return false
        })
    }
    
    @Test("MarkdownParser inline parsing extracts bold, italic, code, math and links")
    func testMarkdownParserInline() {
        let inlineText = "Use **bold** and *italic* with `variable_x` and math $O(N)$ plus [Apple](https://apple.com)."
        let spans = MarkdownParser.parseInline(inlineText)
        
        #expect(spans.contains(.bold("bold")))
        #expect(spans.contains(.italic("italic")))
        #expect(spans.contains(.inlineCode("variable_x")))
        #expect(spans.contains(.inlineMath("O(N)")))
        #expect(spans.contains(.link(text: "Apple", url: "https://apple.com")))
    }
    
    @Test("SyntaxHighlighter correctly categorizes keywords, types, strings and comments")
    func testSyntaxHighlighter() {
        let code = """
        // Calculate sum
        func calculate(items: [Int]) -> Int {
            let total = 42
            return total
        }
        """
        
        let lines = SyntaxHighlighter.highlight(code: code, language: "swift")
        #expect(lines.count == 5)
        
        let firstLineTokens = lines[0]
        #expect(firstLineTokens.contains { $0.category == .comment })
        
        let funcLineTokens = lines[1]
        #expect(funcLineTokens.contains { $0.text == "func" && $0.category == .keyword })
        #expect(funcLineTokens.contains { $0.text == "Int" && $0.category == .type })
        
        let numberLineTokens = lines[2]
        #expect(numberLineTokens.contains { $0.text == "42" && $0.category == .number })
        
        // Also verify AttributedString conversion produces content
        let attrStr = SyntaxHighlighter.attributedString(for: code, language: "swift")
        #expect(!attrStr.characters.isEmpty)
    }
    
    @Test("LaTeXMathFormatter handles symbols, fractions, powers, and Big-O notation")
    func testLaTeXMathFormatter() {
        let formula = #"O(N \log N) \le O(N^2)"#
        let formatted = LaTeXMathFormatter.formatLaTeX(formula)
        #expect(formatted.contains("≤"))
        #expect(formatted.contains("N²"))
        
        let fractionFormula = #"\frac{a + b}{2}"#
        let formattedFraction = LaTeXMathFormatter.formatLaTeX(fractionFormula)
        #expect(formattedFraction.contains("(a + b) / (2)"))
        
        let greekFormula = #"\alpha + \theta \approx \pi"#
        let formattedGreek = LaTeXMathFormatter.formatLaTeX(greekFormula)
        #expect(formattedGreek.contains("α"))
        #expect(formattedGreek.contains("θ"))
        #expect(formattedGreek.contains("≈"))
        #expect(formattedGreek.contains("π"))
    }
    
    @Test("OverlayViewModel manages transcripts, audio meters, and modes")
    @MainActor
    func testOverlayViewModelState() async {
        let db = try! AppDatabase.makeInMemory()
        let vm = OverlayViewModel(database: db)
        
        #expect(vm.isExpanded == true)
        #expect(vm.isPassthrough == false)
        #expect(!vm.availableModes.isEmpty)
        
        // Test audio meter updates
        vm.updateAudioMeters(micRMS: 0.15, systemRMS: 0.0)
        #expect(vm.isAudioActive == true)
        #expect(vm.micRMS == 0.15)
        
        // Test transcript ingestion
        vm.appendTranscript(channel: .microphone, text: "Can you hear me?")
        vm.appendTranscript(channel: .systemLoopback, text: "Yes, loud and clear.")
        #expect(vm.transcripts.count == 2)
        #expect(vm.transcripts[0].speaker == "You")
        #expect(vm.transcripts[1].speaker == "Interviewer")
        
        // Test screen context attachment
        vm.attachScreenContext(ocrText: "Sample OCR problem statement", imageBase64: "data:image/png;base64,abc")
        #expect(vm.attachedOCRSnippet == "Sample OCR problem statement")
        
        // Test simulated streaming
        vm.askAI(prompt: "Explain binary search")
        #expect(vm.isAIStreaming == true)
        
        // Allow brief time for simulated streaming task
        for _ in 0..<30 {
            if !vm.currentAIText.isEmpty { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(!vm.currentAIText.isEmpty)
        #expect(vm.ttftLatencyMs != nil)
        
        // Test clear
        vm.clearSession()
        #expect(vm.currentAIText.isEmpty)
        #expect(vm.transcripts.isEmpty)
        #expect(vm.attachedOCRSnippet == nil)
    }
    
    @Test("StealthPanel hardware stealth and non-activating properties")
    @MainActor
    func testStealthPanelConfiguration() {
        let rect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let panel = StealthPanel(contentRect: rect)
        
        // Invisibility guarantee
        #expect(panel.sharingType == .none)
        
        // Floating level
        #expect(panel.level == .floating)
        
        // Non-activating but keyable
        #expect(panel.canBecomeKey == true)
        #expect(panel.canBecomeMain == false)
        
        // Nudge
        let initialX = panel.frame.origin.x
        panel.nudge(dx: 15, dy: -10)
        #expect(panel.frame.origin.x == initialX + 15)
        
        // Passthrough toggle
        panel.setMousePassthrough(true)
        #expect(panel.ignoresMouseEvents == true)
        panel.setMousePassthrough(false)
        #expect(panel.ignoresMouseEvents == false)
    }
}
