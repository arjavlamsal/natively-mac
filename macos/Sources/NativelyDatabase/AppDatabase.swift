import Foundation
import GRDB
import NativelyCore

public final class AppDatabase: Sendable {
    private let dbWriter: any DatabaseWriter

    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    public static func open(at path: String? = nil) throws -> AppDatabase {
        let databasePath: String
        if let path = path {
            databasePath = path
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let nativelyDir = appSupport.appendingPathComponent("natively", isDirectory: true)
            try FileManager.default.createDirectory(at: nativelyDir, withIntermediateDirectories: true)
            databasePath = nativelyDir.appendingPathComponent("natively.db").path
        }

        var config = Configuration()
        config.qos = .userInitiated
        let dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
        return try AppDatabase(dbQueue)
    }

    public static func makeInMemory() throws -> AppDatabase {
        var config = Configuration()
        config.qos = .userInitiated
        let dbQueue = try DatabaseQueue(configuration: config)
        return try AppDatabase(dbQueue)
    }

    public static let shared: AppDatabase = {
        do {
            return try AppDatabase.open()
        } catch {
            return try! AppDatabase.makeInMemory()
        }
    }()

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        migrator.registerMigration("v1_initial_schema") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS meetings (
                    id TEXT PRIMARY KEY,
                    title TEXT,
                    start_time INTEGER,
                    duration_ms INTEGER,
                    summary_json TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    calendar_event_id TEXT,
                    source TEXT,
                    is_processed INTEGER DEFAULT 1,
                    summary_status TEXT DEFAULT 'completed',
                    embedding_provider TEXT,
                    embedding_dimensions INTEGER
                );

                CREATE TABLE IF NOT EXISTS transcripts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    meeting_id TEXT,
                    speaker TEXT,
                    content TEXT,
                    timestamp_ms INTEGER,
                    FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS ai_interactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    meeting_id TEXT,
                    type TEXT,
                    timestamp INTEGER,
                    user_query TEXT,
                    ai_response TEXT,
                    metadata_json TEXT,
                    FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS modes (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    prompt TEXT NOT NULL,
                    is_custom INTEGER DEFAULT 0,
                    is_active INTEGER DEFAULT 0,
                    description TEXT
                );

                CREATE TABLE IF NOT EXISTS app_state (
                    key TEXT PRIMARY KEY,
                    value TEXT
                );

                CREATE INDEX IF NOT EXISTS idx_transcripts_meeting ON transcripts(meeting_id);
                CREATE INDEX IF NOT EXISTS idx_ai_interactions_meeting ON ai_interactions(meeting_id, timestamp);
            """)
        }

        migrator.registerMigration("v2_vector_rag_schema") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS vector_chunks (
                    id TEXT PRIMARY KEY,
                    meeting_id TEXT,
                    chunk_index INTEGER,
                    text TEXT NOT NULL,
                    embedding_blob BLOB,
                    embedding_dimensions INTEGER,
                    timestamp_ms INTEGER,
                    FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_vector_chunks_meeting ON vector_chunks(meeting_id);
            """)
        }

        return migrator
    }

    // MARK: - Meeting CRUD

    public func saveMeeting(_ meeting: Meeting) throws {
        try dbWriter.write { db in
            let record = MeetingRecord(from: meeting)
            try record.save(db)
        }
    }

    public func fetchMeeting(id: String) throws -> Meeting? {
        try dbWriter.read { db in
            try MeetingRecord.filter(Column("id") == id).fetchOne(db)?.toMeeting()
        }
    }

    public func fetchAllMeetings() throws -> [Meeting] {
        try dbWriter.read { db in
            let records = try MeetingRecord.order(Column("start_time").desc).fetchAll(db)
            return records.map { $0.toMeeting() }
        }
    }

    public func deleteMeeting(id: String) throws {
        try dbWriter.write { db in
            _ = try MeetingRecord.filter(Column("id") == id).deleteAll(db)
        }
    }

    // MARK: - Transcript CRUD

    public func saveTranscriptTurn(_ turn: TranscriptTurn) throws {
        try dbWriter.write { db in
            let record = TranscriptRecord(from: turn)
            try record.save(db)
        }
    }

    public func fetchTranscripts(for meetingId: String) throws -> [TranscriptTurn] {
        try dbWriter.read { db in
            let records = try TranscriptRecord
                .filter(Column("meeting_id") == meetingId)
                .order(Column("timestamp_ms").asc)
                .fetchAll(db)
            return records.map { $0.toTranscriptTurn() }
        }
    }

    // MARK: - AI Interactions CRUD

    public func saveAIInteraction(_ interaction: AIInteraction) throws {
        try dbWriter.write { db in
            let record = AIInteractionRecord(from: interaction)
            try record.save(db)
        }
    }

    public func fetchAIInteractions(for meetingId: String) throws -> [AIInteraction] {
        try dbWriter.read { db in
            let records = try AIInteractionRecord
                .filter(Column("meeting_id") == meetingId)
                .order(Column("timestamp").asc)
                .fetchAll(db)
            return records.map { $0.toAIInteraction() }
        }
    }

    // MARK: - Modes CRUD

    public func saveMode(_ mode: Mode) throws {
        try dbWriter.write { db in
            let record = ModeRecord(from: mode)
            try record.save(db)
        }
    }

    public func fetchModes() throws -> [Mode] {
        try dbWriter.read { db in
            let records = try ModeRecord.fetchAll(db)
            return records.map { $0.toMode() }
        }
    }

    public func fetchMode(id: String) throws -> Mode? {
        try dbWriter.read { db in
            try ModeRecord.filter(Column("id") == id).fetchOne(db)?.toMode()
        }
    }

    public func fetchActiveMode() throws -> Mode? {
        try dbWriter.read { db in
            try ModeRecord.filter(Column("is_active") == 1).fetchOne(db)?.toMode()
        }
    }

    public func setActiveMode(id: String) throws {
        try dbWriter.write { db in
            try db.execute(sql: "UPDATE modes SET is_active = 0")
            try db.execute(sql: "UPDATE modes SET is_active = 1 WHERE id = ?", arguments: [id])
        }
    }

    public func deleteMode(id: String) throws {
        try dbWriter.write { db in
            let wasActive = try ModeRecord.filter(Column("id") == id && Column("is_active") == 1).fetchCount(db) > 0
            _ = try ModeRecord.filter(Column("id") == id).deleteAll(db)
            if wasActive {
                if let fallback = try ModeRecord.fetchOne(db) {
                    try db.execute(sql: "UPDATE modes SET is_active = 1 WHERE id = ?", arguments: [fallback.id])
                }
            }
        }
    }

    public func seedDefaultModesIfEmpty() throws {
        let existing = try fetchModes()
        guard existing.isEmpty else { return }

        let defaults: [(id: String, name: String, prompt: String, description: String, active: Bool)] = [
            ("mode-tech-interview", "Technical Interview", "Provide concise, mathematically rigorous answers with BLUF and code complexity.", "Coding and system design copilot for technical interviews.", true),
            ("mode-looking-for-work", "Job Interview", "Focus on STAR method with clear metrics, ownership, and impactful outcomes.", "Behavioral interviews and career background storytelling.", false),
            ("mode-sales", "Sales & Pitching", "Enterprise sales discovery using MEDDPICC and proactive objection handling.", "Sales qualification, pipeline discovery, and closing.", false),
            ("mode-recruiting", "Recruiting & Hiring", "Assess candidate competency, cultural alignment, and structured interview rubrics.", "Hiring manager and recruiter candidate evaluation.", false),
            ("mode-team-meet", "Team Standup & Sync", "Synthesize sprint blockers, cross-functional dependencies, and deliverables.", "Agile standups, project syncs, and team planning.", false),
            ("mode-lecture", "Lecture & Course", "Capture academic concepts, mathematical derivations, and structured study notes.", "University lectures, seminars, and technical tutorials.", false),
            ("mode-seminar", "Seminar & Keynote", "Executive symposium synthesis, panel themes, and research critique.", "Conferences, industry keynotes, and expert panels.", false),
            ("mode-call-center", "Customer Support", "Empathetic troubleshooting, de-escalation, and root-cause resolution.", "Customer support and client success calls.", false),
            ("mode-negotiation", "Negotiation Coach", "Tactical empathy, calibrated questions, labeling, and counter-proposals.", "Salary, procurement, and commercial contract negotiations.", false),
            ("mode-executive", "Executive Advisor", "High-altitude strategic synthesis with BLUF and trade-off matrices.", "Board meetings, strategy reviews, and C-level syncs.", false),
            ("mode-general", "General Meeting", "Concise, actionable assistance for general conversations.", "Everyday meetings and discussions.", false)
        ]

        for item in defaults {
            let mode = Mode(
                id: item.id,
                name: item.name,
                prompt: item.prompt,
                isCustom: false,
                isActive: item.active,
                description: item.description
            )
            try saveMode(mode)
        }
    }

    // MARK: - App State (KV Store)

    public func getAppState(key: String) throws -> String? {
        try dbWriter.read { db in
            try AppStateRecord.filter(Column("key") == key).fetchOne(db)?.value
        }
    }

    public func setAppState(key: String, value: String?) throws {
        try dbWriter.write { db in
            if let value = value {
                let record = AppStateRecord(key: key, value: value)
                try record.save(db)
            } else {
                _ = try AppStateRecord.filter(Column("key") == key).deleteAll(db)
            }
        }
    }

    // MARK: - Vector Chunks (RAG)

    public func saveVectorChunk(_ chunk: VectorChunk) throws {
        try dbWriter.write { db in
            let record = VectorChunkRecord(from: chunk)
            try record.save(db)
        }
    }

    public func saveVectorChunks(_ chunks: [VectorChunk]) throws {
        try dbWriter.write { db in
            for chunk in chunks {
                let record = VectorChunkRecord(from: chunk)
                try record.save(db)
            }
        }
    }

    public func fetchVectorChunks(meetingId: String? = nil) throws -> [VectorChunk] {
        try dbWriter.read { db in
            let request: QueryInterfaceRequest<VectorChunkRecord>
            if let meetingId = meetingId {
                request = VectorChunkRecord.filter(Column("meeting_id") == meetingId).order(Column("chunk_index").asc)
            } else {
                request = VectorChunkRecord.order(Column("timestamp_ms").desc)
            }
            let records = try request.fetchAll(db)
            return records.map { $0.toVectorChunk() }
        }
    }

    public func deleteVectorChunks(forMeetingId meetingId: String) throws {
        try dbWriter.write { db in
            _ = try VectorChunkRecord.filter(Column("meeting_id") == meetingId).deleteAll(db)
        }
    }
}
