import Foundation

public enum STTEngineType: String, Codable, Sendable, CaseIterable {
    case whisperKit = "whisperkit"
    case appleSpeech = "apple-speech"
    case deepgram = "deepgram"
    case openAIRealtime = "openai-realtime"
    case elevenLabs = "elevenlabs"
    case soniox = "soniox"
}

public enum AIProviderType: String, Codable, Sendable, CaseIterable {
    case anthropic = "anthropic"
    case openAI = "openai"
    case googleGemini = "gemini"
    case groq = "groq"
    case deepSeek = "deepseek"
    case ollama = "ollama"
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var selectedSTTEngine: STTEngineType
    public var selectedAIProvider: AIProviderType
    public var selectedModel: String
    public var activeModeId: String
    public var isStealthModeEnabled: Bool
    public var isAdaptiveDockEnabled: Bool
    public var autoAnswerTriggerDelayMs: Int
    public var primaryMicrophoneId: String?
    public var primarySystemAudioId: String?

    public init(
        selectedSTTEngine: STTEngineType = .whisperKit,
        selectedAIProvider: AIProviderType = .anthropic,
        selectedModel: String = "claude-3-5-sonnet-20241022",
        activeModeId: String = "tech-interview",
        isStealthModeEnabled: Bool = true,
        isAdaptiveDockEnabled: Bool = true,
        autoAnswerTriggerDelayMs: Int = 1200,
        primaryMicrophoneId: String? = nil,
        primarySystemAudioId: String? = nil
    ) {
        self.selectedSTTEngine = selectedSTTEngine
        self.selectedAIProvider = selectedAIProvider
        self.selectedModel = selectedModel
        self.activeModeId = activeModeId
        self.isStealthModeEnabled = isStealthModeEnabled
        self.isAdaptiveDockEnabled = isAdaptiveDockEnabled
        self.autoAnswerTriggerDelayMs = autoAnswerTriggerDelayMs
        self.primaryMicrophoneId = primaryMicrophoneId
        self.primarySystemAudioId = primarySystemAudioId
    }
}
