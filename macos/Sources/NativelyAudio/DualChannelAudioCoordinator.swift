import Foundation
import NativelyCore
import NativelyDatabase

public actor DualChannelAudioCoordinator {
    public typealias TranscriptTurnHandler = @Sendable (TranscriptTurn) -> Void

    private let micService: MicrophoneCaptureService
    private let systemAudioService: SystemAudioCaptureService
    private let routeObserver: AudioRouteObserver
    private let vad: VoiceActivityDetector
    private let transcriptionService: WhisperTranscriptionService
    private let appleSpeechService: AppleSpeechTranscriptionService
    private let database: AppDatabase
    private var sttEngine: STTEngineType = .appleSpeech

    private var activeMeetingId: String?
    private var isRecording = false
    private var turnHandler: TranscriptTurnHandler?

    // Audio sample buffers per channel
    private var micBuffer: [Float] = []
    private var micBufferStartTimeMs: Int64 = 0

    private var systemBuffer: [Float] = []
    private var systemBufferStartTimeMs: Int64 = 0

    public init(
        database: AppDatabase,
        micService: MicrophoneCaptureService = MicrophoneCaptureService(),
        systemAudioService: SystemAudioCaptureService = SystemAudioCaptureService(),
        routeObserver: AudioRouteObserver = AudioRouteObserver(),
        vad: VoiceActivityDetector = VoiceActivityDetector(),
        transcriptionService: WhisperTranscriptionService = WhisperTranscriptionService(),
        appleSpeechService: AppleSpeechTranscriptionService = AppleSpeechTranscriptionService(),
        sttEngine: STTEngineType = .appleSpeech
    ) {
        self.database = database
        self.micService = micService
        self.systemAudioService = systemAudioService
        self.routeObserver = routeObserver
        self.vad = vad
        self.transcriptionService = transcriptionService
        self.appleSpeechService = appleSpeechService
        self.sttEngine = sttEngine

        setupRouteObserver()
    }

    private nonisolated func setupRouteObserver() {
        routeObserver.setHandler { [weak self] in
            Task { [weak self] in
                await self?.handleAudioRouteChange()
            }
        }
    }

    private func handleAudioRouteChange() {
        guard isRecording else { return }
        try? micService.reconfigure()
    }

    public func setSTTEngine(_ engine: STTEngineType) {
        self.sttEngine = engine
    }

    public func setTurnHandler(_ handler: @escaping TranscriptTurnHandler) {
        self.turnHandler = handler
    }

    public func startMeeting(id: String) async throws {
        guard !isRecording else { return }
        self.activeMeetingId = id
        self.isRecording = true
        self.micBuffer.removeAll()
        self.systemBuffer.removeAll()

        micService.setChunkHandler { [weak self] chunk in
            Task { [weak self] in
                await self?.ingestChunk(chunk)
            }
        }

        systemAudioService.setChunkHandler { [weak self] chunk in
            Task { [weak self] in
                await self?.ingestChunk(chunk)
            }
        }

        try micService.start()
        try? await systemAudioService.start()
    }

    public func stopMeeting() async {
        guard isRecording else { return }
        self.isRecording = false
        micService.stop()
        await systemAudioService.stop()

        self.micBuffer.removeAll()
        self.systemBuffer.removeAll()
        self.activeMeetingId = nil
    }

    public func ingestChunk(_ chunk: AudioChunk) async {
        guard isRecording, activeMeetingId != nil else { return }

        switch chunk.channel {
        case .microphone:
            if micBuffer.isEmpty {
                micBufferStartTimeMs = chunk.timestampMs
            }
            micBuffer.append(contentsOf: chunk.samples)

            // When buffer reaches ~2 seconds of audio (32,000 samples at 16kHz)
            if micBuffer.count >= 32000 {
                await flushChannel(.microphone)
            }

        case .systemLoopback:
            if systemBuffer.isEmpty {
                systemBufferStartTimeMs = chunk.timestampMs
            }
            systemBuffer.append(contentsOf: chunk.samples)

            if systemBuffer.count >= 32000 {
                await flushChannel(.systemLoopback)
            }
        }
    }

    private func flushChannel(_ channel: AudioChannel) async {
        guard isRecording else { return }
        let samples: [Float]
        let startTimeMs: Int64
        let speaker: String

        switch channel {
        case .microphone:
            guard !micBuffer.isEmpty else { return }
            samples = micBuffer
            startTimeMs = micBufferStartTimeMs
            speaker = "You"
            micBuffer.removeAll()

        case .systemLoopback:
            guard !systemBuffer.isEmpty else { return }
            samples = systemBuffer
            startTimeMs = systemBufferStartTimeMs
            speaker = "Interviewer"
            systemBuffer.removeAll()
        }

        // Voice Activity Gate: ignore silence frames
        guard vad.containsVoice(samples: samples) else { return }
        guard isRecording, let meetingId = self.activeMeetingId else { return }

        do {
            let segments: [WhisperSegment]
            if sttEngine == .appleSpeech {
                segments = try await appleSpeechService.transcribe(audioSamples: samples)
            } else {
                do {
                    segments = try await transcriptionService.transcribe(audioSamples: samples)
                } catch {
                    // Fall back cleanly to macOS Speech.framework if WhisperKit fails to load or run
                    segments = try await appleSpeechService.transcribe(audioSamples: samples)
                }
            }
            guard isRecording else { return }
            for segment in segments {
                let turn = TranscriptTurn(
                    meetingId: meetingId,
                    speaker: speaker,
                    content: segment.text,
                    timestampMs: startTimeMs + segment.startMs
                )
                try database.saveTranscriptTurn(turn)
                turnHandler?(turn)
            }
        } catch {
            // Log transcription error in development
        }
    }
}
