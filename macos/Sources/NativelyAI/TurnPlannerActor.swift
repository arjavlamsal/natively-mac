import Foundation
import NativelyCore
import NativelyDatabase
import NativelySecurity
import NativelyVision

/// High-level actor coordinating prompt assembly, keychain credentials, fallback streaming, and interaction persistence.
public actor TurnPlannerActor {
    private let database: AppDatabase
    private let keychain: KeychainManager
    private let fallbackEngine: FallbackLadderEngine
    private let clients: [AIProviderType: StreamingAIProvider]
    
    public init(
        database: AppDatabase,
        keychain: KeychainManager = .shared,
        fallbackEngine: FallbackLadderEngine = FallbackLadderEngine(),
        customClients: [AIProviderType: StreamingAIProvider]? = nil
    ) {
        self.database = database
        self.keychain = keychain
        self.fallbackEngine = fallbackEngine
        
        if let custom = customClients {
            self.clients = custom
        } else {
            self.clients = [
                .anthropic: AnthropicStreamingClient(),
                .openAI: OpenAICompatibleStreamingClient.openAI(),
                .groq: OpenAICompatibleStreamingClient.groq(),
                .deepSeek: OpenAICompatibleStreamingClient.deepseek(),
                .googleGemini: GeminiStreamingClient(),
                .ollama: OllamaStreamingClient()
            ]
        }
    }
    
    /// Resolves the API key for a provider from the macOS Keychain.
    public func resolveAPIKey(for provider: AIProviderType) async -> String? {
        let keyName: String
        switch provider {
        case .anthropic: keyName = "anthropic_api_key"
        case .openAI: keyName = "openai_api_key"
        case .googleGemini: keyName = "gemini_api_key"
        case .groq: keyName = "groq_api_key"
        case .deepSeek: keyName = "deepseek_api_key"
        case .ollama: return nil
        }
        
        return try? await keychain.get(key: keyName)
    }
    
    /// Assembles context, resolves keys, runs the fallback streaming ladder, and saves the interaction to GRDB.
    public func generateAnswer(
        question: String,
        meetingId: String? = nil,
        modeId: String = "technical",
        screenContext: ScreenContext? = nil,
        customLadder: [FallbackRung]? = nil
    ) async throws -> FallbackResult {
        // 1. Fetch recent transcript context from the database if meetingId is provided
        var conversationHistory: [AIMessage] = []
        if let mId = meetingId {
            let turns = (try? database.fetchTranscripts(for: mId)) ?? []
            conversationHistory = ModePromptBuilder.formatConversationHistory(turns: turns, maxTurns: 8)
        }
        
        // 2. Fetch mode custom prompt if available
        let mode = try? database.fetchMode(id: modeId)
        let systemPrompt = ModePromptBuilder.buildSystemPrompt(
            modeId: modeId,
            customPrompt: mode?.prompt,
            screenContext: screenContext
        )
        
        // 3. Append latest user question
        var userBase64Images: [String]? = nil
        if let screen = screenContext {
            userBase64Images = [screen.base64DataUrl]
        }
        let userMessage = AIMessage(role: .user, content: question, base64Images: userBase64Images)
        conversationHistory.append(userMessage)
        
        let ladder = customLadder ?? FallbackLadderEngine.defaultLadder
        
        // 4. Execute streaming request via fallback engine
        let result = try await fallbackEngine.executeStream(
            ladder: ladder,
            clientResolver: { [weak self] provider in
                self?.clients[provider]
            },
            keyResolver: { [weak self] provider in
                await self?.resolveAPIKey(for: provider)
            },
            baseRequest: { modelName in
                AIRequest(
                    model: modelName,
                    systemPrompt: systemPrompt,
                    messages: conversationHistory,
                    temperature: 0.4,
                    maxTokens: 2048
                )
            }
        )
        
        // 5. Wrap stream so that when finished, the full answer is recorded in GRDB
        let accumulatedTextActor = TextAccumulator()
        let databaseRef = self.database
        let pUsed = result.providerUsed
        let mUsed = result.modelUsed
        
        let wrappedStream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await chunk in result.stream {
                        await accumulatedTextActor.append(chunk)
                        continuation.yield(chunk)
                    }
                    
                    let fullAnswer = await accumulatedTextActor.getText()
                    if let mId = meetingId, !fullAnswer.isEmpty {
                        let metadataDict = ["provider": pUsed.rawValue, "model": mUsed]
                        let metaJson = (try? JSONSerialization.data(withJSONObject: metadataDict)).flatMap { String(data: $0, encoding: .utf8) }
                        let interaction = AIInteraction(
                            meetingId: mId,
                            type: "answer",
                            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                            userQuery: question,
                            aiResponse: fullAnswer,
                            metadataJson: metaJson
                        )
                        try? databaseRef.saveAIInteraction(interaction)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        
        return FallbackResult(
            stream: wrappedStream,
            providerUsed: result.providerUsed,
            modelUsed: result.modelUsed
        )
    }
}

/// Helper actor accumulating stream chunks safely.
private actor TextAccumulator {
    private var buffer = ""
    func append(_ chunk: String) { buffer += chunk }
    func getText() -> String { buffer }
}
