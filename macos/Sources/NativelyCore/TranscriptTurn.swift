import Foundation

public struct TranscriptTurn: Codable, Sendable, Identifiable, Equatable {
    public var id: Int64?
    public let meetingId: String
    public let speaker: String
    public let content: String
    public let timestampMs: Int64

    public init(
        id: Int64? = nil,
        meetingId: String,
        speaker: String,
        content: String,
        timestampMs: Int64
    ) {
        self.id = id
        self.meetingId = meetingId
        self.speaker = speaker
        self.content = content
        self.timestampMs = timestampMs
    }
}

public struct AIInteraction: Codable, Sendable, Identifiable, Equatable {
    public var id: Int64?
    public let meetingId: String
    public let type: String
    public let timestamp: Int64
    public let userQuery: String?
    public let aiResponse: String?
    public let metadataJson: String?

    public init(
        id: Int64? = nil,
        meetingId: String,
        type: String,
        timestamp: Int64,
        userQuery: String? = nil,
        aiResponse: String? = nil,
        metadataJson: String? = nil
    ) {
        self.id = id
        self.meetingId = meetingId
        self.type = type
        self.timestamp = timestamp
        self.userQuery = userQuery
        self.aiResponse = aiResponse
        self.metadataJson = metadataJson
    }
}
