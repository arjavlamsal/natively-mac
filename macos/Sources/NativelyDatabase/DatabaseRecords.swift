import Foundation
import GRDB
import NativelyCore

// MARK: - MeetingRecord
public struct MeetingRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "meetings"

    public var id: String
    public var title: String?
    public var start_time: Int64?
    public var duration_ms: Int64?
    public var summary_json: String?
    public var created_at: String?
    public var calendar_event_id: String?
    public var source: String?
    public var is_processed: Int
    public var summary_status: String?
    public var embedding_provider: String?
    public var embedding_dimensions: Int?

    public init(from meeting: Meeting) {
        self.id = meeting.id
        self.title = meeting.title
        self.start_time = meeting.startTime
        self.duration_ms = meeting.durationMs
        self.summary_json = meeting.summaryJson
        self.created_at = meeting.createdAt
        self.calendar_event_id = meeting.calendarEventId
        self.source = meeting.source
        self.is_processed = meeting.isProcessed ? 1 : 0
        self.summary_status = meeting.summaryStatus
        self.embedding_provider = meeting.embeddingProvider
        self.embedding_dimensions = meeting.embeddingDimensions
    }

    public func toMeeting() -> Meeting {
        Meeting(
            id: id,
            title: title,
            startTime: start_time,
            durationMs: duration_ms,
            summaryJson: summary_json,
            createdAt: created_at,
            calendarEventId: calendar_event_id,
            source: source,
            isProcessed: is_processed != 0,
            summaryStatus: summary_status,
            embeddingProvider: embedding_provider,
            embeddingDimensions: embedding_dimensions
        )
    }
}

// MARK: - TranscriptRecord
public struct TranscriptRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "transcripts"

    public var id: Int64?
    public var meeting_id: String
    public var speaker: String
    public var content: String
    public var timestamp_ms: Int64

    public init(from turn: TranscriptTurn) {
        self.id = turn.id
        self.meeting_id = turn.meetingId
        self.speaker = turn.speaker
        self.content = turn.content
        self.timestamp_ms = turn.timestampMs
    }

    public func toTranscriptTurn() -> TranscriptTurn {
        TranscriptTurn(
            id: id,
            meetingId: meeting_id,
            speaker: speaker,
            content: content,
            timestampMs: timestamp_ms
        )
    }
}

// MARK: - AIInteractionRecord
public struct AIInteractionRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "ai_interactions"

    public var id: Int64?
    public var meeting_id: String
    public var type: String
    public var timestamp: Int64
    public var user_query: String?
    public var ai_response: String?
    public var metadata_json: String?

    public init(from item: AIInteraction) {
        self.id = item.id
        self.meeting_id = item.meetingId
        self.type = item.type
        self.timestamp = item.timestamp
        self.user_query = item.userQuery
        self.ai_response = item.aiResponse
        self.metadata_json = item.metadataJson
    }

    public func toAIInteraction() -> AIInteraction {
        AIInteraction(
            id: id,
            meetingId: meeting_id,
            type: type,
            timestamp: timestamp,
            userQuery: user_query,
            aiResponse: ai_response,
            metadataJson: metadata_json
        )
    }
}

// MARK: - ModeRecord
public struct ModeRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "modes"

    public var id: String
    public var name: String
    public var prompt: String
    public var is_custom: Int
    public var is_active: Int
    public var description: String?

    public init(from mode: Mode) {
        self.id = mode.id
        self.name = mode.name
        self.prompt = mode.prompt
        self.is_custom = mode.isCustom ? 1 : 0
        self.is_active = mode.isActive ? 1 : 0
        self.description = mode.description
    }

    public func toMode() -> Mode {
        Mode(
            id: id,
            name: name,
            prompt: prompt,
            isCustom: is_custom != 0,
            isActive: is_active != 0,
            description: description
        )
    }
}

// MARK: - AppStateRecord
public struct AppStateRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "app_state"

    public var key: String
    public var value: String?

    public init(key: String, value: String? = nil) {
        self.key = key
        self.value = value
    }
}

// MARK: - VectorChunkRecord
public struct VectorChunkRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "vector_chunks"

    public var id: String
    public var meeting_id: String?
    public var chunk_index: Int
    public var text: String
    public var embedding_blob: Data?
    public var embedding_dimensions: Int?
    public var timestamp_ms: Int64

    public init(from chunk: VectorChunk) {
        self.id = chunk.id
        self.meeting_id = chunk.meetingId
        self.chunk_index = chunk.chunkIndex
        self.text = chunk.text
        self.timestamp_ms = chunk.timestampMs
        
        if let floats = chunk.embedding {
            self.embedding_dimensions = floats.count
            self.embedding_blob = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        } else {
            self.embedding_dimensions = nil
            self.embedding_blob = nil
        }
    }

    public func toVectorChunk() -> VectorChunk {
        var floats: [Float]? = nil
        if let blob = embedding_blob, let dims = embedding_dimensions, dims > 0 {
            floats = blob.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }
        return VectorChunk(
            id: id,
            meetingId: meeting_id,
            chunkIndex: chunk_index,
            text: text,
            embedding: floats,
            timestampMs: timestamp_ms
        )
    }
}
