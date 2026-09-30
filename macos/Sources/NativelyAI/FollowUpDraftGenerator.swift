import Foundation
import NativelyCore

public enum FollowUpTone: String, Codable, Sendable, CaseIterable {
    case concise = "concise"
    case formal = "formal"
    case friendly = "friendly"
    case casual = "casual"
    
    public var displayName: String {
        switch self {
        case .concise: return "Concise & Direct"
        case .formal: return "Executive & Formal"
        case .friendly: return "Warm & Collaborative"
        case .casual: return "Casual & Quick"
        }
    }
}

public enum FollowUpDraftType: String, Codable, Sendable, CaseIterable {
    case email = "email"
    case projectUpdate = "project_update"
    case interviewFeedback = "interview_feedback"
    case studyNotes = "study_notes"
    
    public var displayName: String {
        switch self {
        case .email: return "Follow-Up Email"
        case .projectUpdate: return "Project / Team Update"
        case .interviewFeedback: return "Interview Feedback"
        case .studyNotes: return "Study Notes"
        }
    }
}

public struct FollowUpDraft: Codable, Sendable, Equatable {
    public let subject: String
    public let greeting: String
    public let body: String
    public let actionItems: [String]
    public let closing: String
    public let tone: FollowUpTone
    public let draftType: FollowUpDraftType
    
    public init(
        subject: String,
        greeting: String,
        body: String,
        actionItems: [String],
        closing: String,
        tone: FollowUpTone,
        draftType: FollowUpDraftType
    ) {
        self.subject = subject
        self.greeting = greeting
        self.body = body
        self.actionItems = actionItems
        self.closing = closing
        self.tone = tone
        self.draftType = draftType
    }
    
    /// Full ready-to-copy formatted text representation.
    public var fullFormattedText: String {
        var lines: [String] = []
        if !subject.isEmpty {
            lines.append("Subject: \(subject)")
            lines.append("")
        }
        lines.append(greeting)
        lines.append("")
        lines.append(body)
        
        if !actionItems.isEmpty {
            lines.append("")
            lines.append("Next Steps / Action Items:")
            for item in actionItems {
                lines.append("• \(item)")
            }
        }
        
        lines.append("")
        lines.append(closing)
        return lines.joined(separator: "\n")
    }
}

/// Generates structured, high-polish follow-up emails, interview feedback, and project recaps
/// tailored to meeting mode and preferred communication tone.
public struct FollowUpDraftGenerator: Sendable {
    
    public init() {}
    
    /// Resolves the default draft type for a given meeting mode.
    public static func defaultDraftType(for modeId: String?) -> FollowUpDraftType {
        guard let mode = modeId?.lowercased() else { return .email }
        if mode.contains("interview") || mode.contains("coding") {
            return .interviewFeedback
        } else if mode.contains("team") || mode.contains("standup") {
            return .projectUpdate
        } else if mode.contains("lecture") || mode.contains("seminar") {
            return .studyNotes
        } else {
            return .email
        }
    }
    
    /// Generates a follow-up draft using meeting metadata and summarized notes.
    public static func generateDraft(
        meeting: Meeting,
        modeId: String? = nil,
        tone: FollowUpTone = .concise,
        draftType: FollowUpDraftType? = nil
    ) -> FollowUpDraft {
        let type = draftType ?? defaultDraftType(for: modeId)
        let summary = meeting.parsedSummary
        let meetingTitle = meeting.title ?? "Our Discussion"
        let overview = summary?.overview ?? "Thank you for the productive discussion today."
        let actionItems = summary?.actionItems ?? []
        let keyPoints = summary?.keyPoints ?? []
        
        let subject: String
        let greeting: String
        let closing: String
        var bodySections: [String] = []
        
        switch type {
        case .interviewFeedback:
            subject = "Technical Interview Notes & Assessment: \(meetingTitle)"
            greeting = tone == .formal ? "Dear Hiring Team," : "Hi Team,"
            closing = tone == .formal ? "Best regards,\nEngineering Team" : "Best,\nEngineering"
            
            bodySections.append("Here is the technical synthesis from today's session regarding \(meetingTitle):")
            bodySections.append(overview)
            if !keyPoints.isEmpty {
                bodySections.append("Key Technical Observations:\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n"))
            }
            
        case .projectUpdate:
            subject = "Project Update & Sync Notes: \(meetingTitle)"
            greeting = tone == .formal ? "Hello Team," : "Hey everyone,"
            closing = tone == .formal ? "Sincerely,\nProject Lead" : "Cheers,\nTeam"
            
            bodySections.append("Quick recap from our sync:")
            bodySections.append(overview)
            if !keyPoints.isEmpty {
                bodySections.append("Decisions & Highlights:\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n"))
            }
            
        case .studyNotes:
            subject = "Lecture & Discussion Notes: \(meetingTitle)"
            greeting = "Summary Notes"
            closing = "— Compiled with Natively"
            
            bodySections.append("Core Concepts Covered:")
            bodySections.append(overview)
            if !keyPoints.isEmpty {
                bodySections.append("Key Takeaways:\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n"))
            }
            
        case .email:
            subject = "Follow-up: \(meetingTitle)"
            switch tone {
            case .formal:
                greeting = "Dear Colleagues,"
                closing = "Sincerely,\nNatively Team"
            case .concise:
                greeting = "Hi all,"
                closing = "Best,\nNatively"
            case .friendly:
                greeting = "Hi everyone,"
                closing = "Warm regards,\nNatively Team"
            case .casual:
                greeting = "Hey all,"
                closing = "Thanks!\nNatively"
            }
            
            bodySections.append(overview)
            if !keyPoints.isEmpty {
                bodySections.append("Key Points Discussed:\n" + keyPoints.map { "• \($0)" }.joined(separator: "\n"))
            }
        }
        
        return FollowUpDraft(
            subject: subject,
            greeting: greeting,
            body: bodySections.joined(separator: "\n\n"),
            actionItems: actionItems,
            closing: closing,
            tone: tone,
            draftType: type
        )
    }
}
