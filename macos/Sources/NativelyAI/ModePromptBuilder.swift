import Foundation
import NativelyCore
import NativelyVision

/// Compiles tailored system prompts and contextual instructions for live meetings and interviews.
public struct ModePromptBuilder: Sendable {
    
    public init() {}
    
    /// Builds the system prompt for a specific interview/meeting mode.
    public static func buildSystemPrompt(
        modeId: String,
        customPrompt: String? = nil,
        screenContext: ScreenContext? = nil
    ) -> String {
        var basePrompt = ""
        
        if let custom = customPrompt, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            basePrompt = custom
        } else {
            switch modeId.lowercased() {
            case "technical", "coding", "interview":
            basePrompt = """
            You are Natively, an elite real-time technical interview copilot.
            Your output will be read at a glance during a live coding interview.
            
            OPERATIONAL RULES:
            1. No pleasantries, preambles, or conversational filler (never say "Sure!", "Here is the solution:", etc.).
            2. For coding questions:
               - State the core algorithmic intuition in 1-2 bullet points.
               - State Time Complexity and Space Complexity (e.g. O(N) time, O(1) space).
               - Provide the clean, idiomatic, optimal implementation with minimal comments.
               - Highlight 1-2 critical edge cases to mention to the interviewer.
            3. For system design:
               - Clarify requirements & scale (QPS, storage, latency).
               - Propose high-level architecture components (Load Balancer, API Gateway, DB partition, Caching).
               - Discuss bottlenecks and trade-offs directly.
            4. Keep responses punchy, formatted in GitHub markdown with bold headers and code blocks.
            """
            
        case "negotiation":
            basePrompt = """
            You are Natively, an expert negotiation coach trained in tactical empathy and calibrated questioning.
            
            OPERATIONAL RULES:
            1. Identify the counterpart's underlying constraints, emotional drivers, and unspoken anchors.
            2. Suggest calibrated open-ended questions starting with "How" or "What" (e.g., "How am I supposed to do that?").
            3. Use labeling ("It seems like...", "It sounds like...") to defuse resistance.
            4. Provide immediate, exact phrasing the user can say aloud verbatim.
            """
            
        case "sales":
            basePrompt = """
            You are Natively, a world-class enterprise sales strategist using MEDDPICC and challenger methodologies.
            
            OPERATIONAL RULES:
            1. Focus on discovering the customer's quantifiable business pain and economic impact.
            2. Pinpoint the Economic Buyer, Decision Criteria, and Decision Process.
            3. Provide crisp objection-handling responses and high-leverage discovery questions.
            """
            
        case "executive", "leadership":
            basePrompt = """
            You are Natively, an executive advisor delivering high-impact strategic synthesis.
            
            OPERATIONAL RULES:
            1. Use BLUF (Bottom Line Up Front): deliver the conclusion or decision in the first sentence.
            2. Structure into maximum 3 bullet points: Context/Problem, Strategic Trade-offs, Recommended Action.
            3. Eliminate operational weeds; maintain strategic altitude.
            """
            
        default:
            basePrompt = """
            You are Natively, a modern native macOS meeting copilot.
            Provide concise, accurate, and actionable answers to live conversation questions.
            """
            }
        }
        
        // Append multimodal or OCR screen context if present
        if let screen = screenContext, !screen.ocrResult.isEmpty {
            basePrompt += """
            
            
            ==================================================
            CURRENTLY VISIBLE SCREEN CONTENT (OCR EXTRACTION):
            ==================================================
            \(screen.ocrResult.fullText)
            ==================================================
            Note: The user or interviewer is referencing this on-screen content. Incorporate it seamlessly.
            """
        }
        
        return basePrompt
    }
    
    /// Formats recent transcript turns into conversational history.
    public static func formatConversationHistory(
        turns: [TranscriptTurn],
        maxTurns: Int = 10
    ) -> [AIMessage] {
        let recent = turns.suffix(maxTurns)
        return recent.map { turn in
            let role: AIMessageRole = (turn.speaker == "You" || turn.speaker == "User") ? .assistant : .user
            let prefix = turn.speaker.isEmpty ? "" : "[\(turn.speaker)] "
            return AIMessage(role: role, content: "\(prefix)\(turn.content)")
        }
    }
}
