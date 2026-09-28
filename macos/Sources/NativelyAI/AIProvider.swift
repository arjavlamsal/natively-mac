import Foundation
import NativelyCore
import NativelyVision

/// Extensions on canonical NativelyCore.AIProviderType
extension AIProviderType {
    public var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openAI: return "OpenAI"
        case .googleGemini: return "Google Gemini"
        case .groq: return "Groq Cloud"
        case .deepSeek: return "DeepSeek"
        case .ollama: return "Ollama (Local)"
        }
    }
    
    public var defaultModel: String {
        switch self {
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .openAI: return "gpt-4o"
        case .googleGemini: return "gemini-1.5-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .deepSeek: return "deepseek-chat"
        case .ollama: return "llama3.2"
        }
    }
    
    public var isLocal: Bool {
        self == .ollama
    }
}

/// Metadata describing a specific LLM model.
public struct ModelDescriptor: Sendable, Hashable {
    public let id: String
    public let name: String
    public let provider: AIProviderType
    public let contextWindow: Int
    public let supportsVision: Bool
    
    public init(
        id: String,
        name: String,
        provider: AIProviderType,
        contextWindow: Int = 128_000,
        supportsVision: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.contextWindow = contextWindow
        self.supportsVision = supportsVision
    }
}

/// The role of a message participant.
public enum AIMessageRole: String, Codable, Sendable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

/// A structured message in an LLM conversation.
public struct AIMessage: Sendable, Codable, Equatable {
    public let role: AIMessageRole
    public let content: String
    public let base64Images: [String]?
    
    public init(role: AIMessageRole, content: String, base64Images: [String]? = nil) {
        self.role = role
        self.content = content
        self.base64Images = base64Images
    }
}

/// A unified request structure sent to any streaming provider client.
public struct AIRequest: Sendable {
    public let model: String
    public let systemPrompt: String?
    public let messages: [AIMessage]
    public let temperature: Double?
    public let maxTokens: Int?
    
    public init(
        model: String,
        systemPrompt: String? = nil,
        messages: [AIMessage],
        temperature: Double? = 0.5,
        maxTokens: Int? = 2048
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// Common protocol implemented by all native streaming clients.
public protocol StreamingAIProvider: Sendable {
    var providerType: AIProviderType { get }
    func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error>
}
