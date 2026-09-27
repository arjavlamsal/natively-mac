import Foundation

public struct ActionItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let text: String
    public let owner: String?
    public let deadline: String?
    public let completed: Bool?

    public init(id: String = UUID().uuidString, text: String, owner: String? = nil, deadline: String? = nil, completed: Bool? = false) {
        self.id = id
        self.text = text
        self.owner = owner
        self.deadline = deadline
        self.completed = completed
    }
}

public struct DecisionItem: Codable, Sendable, Equatable {
    public let id: String?
    public let text: String
    public let context: String?

    public init(id: String? = UUID().uuidString, text: String, context: String? = nil) {
        self.id = id
        self.text = text
        self.context = context
    }
}

public struct QuestionItem: Codable, Sendable, Equatable {
    public let id: String?
    public let text: String
    public let status: String?

    public init(id: String? = UUID().uuidString, text: String, status: String? = nil) {
        self.id = id
        self.text = text
        self.status = status
    }
}

public struct RiskItem: Codable, Sendable, Equatable {
    public let id: String?
    public let text: String
    public let severity: String?

    public init(id: String? = UUID().uuidString, text: String, severity: String? = nil) {
        self.id = id
        self.text = text
        self.severity = severity
    }
}

public struct DetailedSummary: Codable, Sendable, Equatable {
    public var overview: String?
    public var actionItems: [String]?
    public var actionItemsV3: [ActionItem]?
    public var keyPoints: [String]?
    public var tldr: [String]?
    public var decisions: [DecisionItem]?
    public var openQuestions: [QuestionItem]?
    public var risks: [RiskItem]?
    public var followUpDraft: String?

    public init(
        overview: String? = nil,
        actionItems: [String]? = nil,
        actionItemsV3: [ActionItem]? = nil,
        keyPoints: [String]? = nil,
        tldr: [String]? = nil,
        decisions: [DecisionItem]? = nil,
        openQuestions: [QuestionItem]? = nil,
        risks: [RiskItem]? = nil,
        followUpDraft: String? = nil
    ) {
        self.overview = overview
        self.actionItems = actionItems
        self.actionItemsV3 = actionItemsV3
        self.keyPoints = keyPoints
        self.tldr = tldr
        self.decisions = decisions
        self.openQuestions = openQuestions
        self.risks = risks
        self.followUpDraft = followUpDraft
    }
}

public struct Meeting: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String?
    public var startTime: Int64?
    public var durationMs: Int64?
    public var summaryJson: String?
    public var createdAt: String?
    public var calendarEventId: String?
    public var source: String?
    public var isProcessed: Bool
    public var summaryStatus: String?
    public var embeddingProvider: String?
    public var embeddingDimensions: Int?

    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        startTime: Int64? = nil,
        durationMs: Int64? = nil,
        summaryJson: String? = nil,
        createdAt: String? = nil,
        calendarEventId: String? = nil,
        source: String? = "manual",
        isProcessed: Bool = true,
        summaryStatus: String? = "completed",
        embeddingProvider: String? = nil,
        embeddingDimensions: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.durationMs = durationMs
        self.summaryJson = summaryJson
        self.createdAt = createdAt
        self.calendarEventId = calendarEventId
        self.source = source
        self.isProcessed = isProcessed
        self.summaryStatus = summaryStatus
        self.embeddingProvider = embeddingProvider
        self.embeddingDimensions = embeddingDimensions
    }

    public var parsedSummary: DetailedSummary? {
        guard let summaryJson, let data = summaryJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DetailedSummary.self, from: data)
    }
}
