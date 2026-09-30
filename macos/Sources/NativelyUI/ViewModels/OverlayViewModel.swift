import SwiftUI
import Combine
import NativelyCore
import NativelyDatabase
import NativelyAudio
import NativelyVision
import NativelyAI

/// Descriptor for AI models selectable in the overlay UI.
public struct AIModelInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
    public let providerType: AIProviderType
    public let subtitle: String
    public let isFast: Bool
    
    public init(
        id: String,
        name: String,
        provider: String,
        providerType: AIProviderType,
        subtitle: String = "",
        isFast: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.providerType = providerType
        self.subtitle = subtitle
        self.isFast = isFast
    }
}

/// Web context attached from Companion browser extension.
public struct WebPageContext: Equatable, Sendable {
    public let url: String
    public let domain: String
    public let title: String
    public let chars: Int
    
    public init(url: String, domain: String, title: String, chars: Int) {
        self.url = url
        self.domain = domain
        self.title = title
        self.chars = chars
    }
}

/// View model driving the stealth overlay UI and bridging audio, vision, AI, and persistence.
@MainActor
public final class OverlayViewModel: ObservableObject {
    
    // UI State
    @Published public var isExpanded: Bool = true
    @Published public var isPassthrough: Bool = false
    @Published public var isFocusingPrompt: Bool = false
    @Published public var quickPromptText: String = ""
    @Published public var isQuickSettingsPresented: Bool = false
    @Published public var isModelSelectorPresented: Bool = false
    @Published public var showJumpToLatest: Bool = false
    @Published public var isDirectAssist: Bool = false
    @Published public var isMeetingActive: Bool = false
    
    // Audio Activity
    @Published public var isAudioActive: Bool = false
    @Published public var micRMS: Float = 0.0
    @Published public var systemRMS: Float = 0.0
    @Published public var isManualRecording: Bool = false
    
    // Transcripts
    @Published public var transcripts: [TranscriptTurn] = []
    @Published public var showRollingTranscript: Bool = true
    
    // Mode
    @Published public var activeMode: Mode
    @Published public var availableModes: [Mode] = []
    
    // Multi-turn Chat Stream History
    @Published public var messages: [OverlayMessage] = []
    @Published public var isAIStreaming: Bool = false
    @Published public var currentAIText: String = ""
    @Published public var currentProviderName: String = "Gemini 3.5 Flash Lite"
    @Published public var ttftLatencyMs: Double? = nil
    
    public static let defaultModels: [AIModelInfo] = [
        // Google Gemini
        AIModelInfo(id: "gemini-3.5-flash-lite", name: "Gemini 3.5 Flash Lite", provider: "Google", providerType: .googleGemini, subtitle: "Ultra-fast lowest latency", isFast: true),
        AIModelInfo(id: "gemini-3.8-flash", name: "Gemini 3.8 Flash", provider: "Google", providerType: .googleGemini, subtitle: "Next-gen multimodal reasoning", isFast: true),
        AIModelInfo(id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro", provider: "Google", providerType: .googleGemini, subtitle: "Frontier reasoning & complex logic"),
        
        // Anthropic Claude
        AIModelInfo(id: "claude-3-7-sonnet", name: "Claude 3.7 Sonnet", provider: "Anthropic", providerType: .anthropic, subtitle: "Hybrid reasoning & coding depth"),
        AIModelInfo(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: "Anthropic", providerType: .anthropic, subtitle: "Balanced speed & nuanced analysis"),
        AIModelInfo(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: "Anthropic", providerType: .anthropic, subtitle: "Rapid responses & concise answers", isFast: true),
        
        // OpenAI
        AIModelInfo(id: "gpt-4o", name: "GPT-4o", provider: "OpenAI", providerType: .openAI, subtitle: "Versatile omni flagship"),
        AIModelInfo(id: "o3-mini", name: "o3-mini", provider: "OpenAI", providerType: .openAI, subtitle: "High-reasoning STEM & coding", isFast: true),
        
        // Groq Cloud
        AIModelInfo(id: "llama-3.3-70b-versatile", name: "Llama 3.3 70B", provider: "Groq", providerType: .groq, subtitle: "LPU-accelerated ultra-low TTFT", isFast: true),
        
        // DeepSeek
        AIModelInfo(id: "deepseek-chat", name: "DeepSeek V3", provider: "DeepSeek", providerType: .deepSeek, subtitle: "High performance open reasoning"),
        AIModelInfo(id: "deepseek-reasoner", name: "DeepSeek R1", provider: "DeepSeek", providerType: .deepSeek, subtitle: "Deep chain-of-thought problem solving")
    ]
    
    // Active Model
    @Published public var currentModel: AIModelInfo = defaultModels[0] {
        didSet {
            UserDefaults.standard.set(currentModel.id, forKey: "natively_selected_model_id")
        }
    }
    @Published public var availableModels: [AIModelInfo] = defaultModels
    
    // Vision / Screen Context
    @Published public var attachedOCRSnippet: String? = nil
    @Published public var attachedImageBase64: String? = nil
    
    // Web DOM Context
    @Published public var attachedWebContext: WebPageContext? = nil
    
    // Callbacks
    public var onEndMeeting: (@MainActor () -> Void)?
    public var onOpenLauncher: (@MainActor () -> Void)?
    public var onCropTrigger: (@MainActor () -> Void)?
    
    // Services
    public let database: AppDatabase
    public var currentMeetingId: String?
    private var turnPlanner: TurnPlannerActor?
    private var streamingTask: Task<Void, Never>?
    
    public init(database: AppDatabase = .shared) {
        self.database = database
        
        let defaultMode = Mode(
            id: "mode-tech-interview",
            name: "Technical Interview",
            prompt: "Provide concise, mathematically rigorous answers with BLUF and code complexity.",
            isCustom: false,
            isActive: true
        )
        self.activeMode = defaultMode
        self.availableModes = [defaultMode]
        
        // Restore saved model selection if available
        if let savedModelId = UserDefaults.standard.string(forKey: "natively_selected_model_id"),
           let match = Self.defaultModels.first(where: { $0.id == savedModelId }) {
            self.currentModel = match
            self.currentProviderName = "\(match.name)"
        }
        
        loadInitialState()
    }
    
    public func configureTurnPlanner(planner: TurnPlannerActor) {
        self.turnPlanner = planner
    }
    
    /// Loads initial modes and state from the local database.
    public func loadInitialState() {
        do {
            let modes = try database.fetchModes()
            if !modes.isEmpty {
                self.availableModes = modes
                if let active = try database.fetchActiveMode() {
                    self.activeMode = active
                } else if let first = modes.first {
                    self.activeMode = first
                }
            }
        } catch {
            // Use defaults
        }
        
        if let savedModelId = UserDefaults.standard.string(forKey: "natively_selected_model_id"),
           let match = availableModels.first(where: { $0.id == savedModelId }) {
            self.currentModel = match
            self.currentProviderName = match.name
        }
    }
    
    /// Selects and persists the active AI mode.
    public func selectMode(_ mode: Mode) {
        self.activeMode = mode
        try? database.setActiveMode(id: mode.id)
    }
    
    /// Ingests a new live transcript turn from the audio pipeline.
    public func appendTranscript(channel: AudioChannel, text: String) {
        appendTranscript(speaker: channel.defaultSpeakerLabel, text: text)
    }

    /// Ingests a transcript turn with explicit speaker name.
    public func appendTranscript(speaker: String, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let meetingId = currentMeetingId ?? "live-session"
        let turn = TranscriptTurn(
            meetingId: meetingId,
            speaker: speaker,
            content: text,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        transcripts.append(turn)
        
        // Auto-persist if meeting is active
        if currentMeetingId != nil {
            try? database.saveTranscriptTurn(turn)
        }
    }
    
    /// Updates live audio RMS meter levels.
    public func updateAudioMeters(micRMS: Float, systemRMS: Float) {
        self.micRMS = micRMS
        self.systemRMS = systemRMS
        self.isAudioActive = micRMS > 0.05 || systemRMS > 0.05
    }
    
    /// Attaches screen context from an interactive crop or full screen capture.
    public func attachScreenContext(ocrText: String, imageBase64: String?) {
        self.attachedOCRSnippet = ocrText
        self.attachedImageBase64 = imageBase64
    }
    
    /// Clears active screen context.
    public func clearScreenContext() {
        self.attachedOCRSnippet = nil
        self.attachedImageBase64 = nil
    }
    
    /// Attaches web page DOM context received from browser companion extension.
    public func attachWebContext(url: String, title: String, charCount: Int) {
        let domain = URL(string: url)?.host ?? url
        self.attachedWebContext = WebPageContext(url: url, domain: domain, title: title, chars: charCount)
    }
    
    /// Clears attached web context.
    public func clearWebContext() {
        self.attachedWebContext = nil
    }
    
    /// Toggles manual speech recording ("Answer" button).
    public func toggleManualRecording() {
        isManualRecording.toggle()
        if !isManualRecording {
            // When stopped, trigger what to say
            triggerQuickAction(presetNumber: 1)
        }
    }
    
    /// Stops the active meeting session and updates local state.
    public func stopMeeting() {
        if let onEndMeeting {
            onEndMeeting()
        } else {
            isMeetingActive = false
            currentMeetingId = nil
            isExpanded = false
        }
    }
    
    /// Submits a question/prompt to the streaming AI engine, generating user and assistant messages.
    public func askAI(prompt: String, isQuickAction: Bool = false, actionKind: String? = nil) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        streamingTask?.cancel()
        isAIStreaming = true
        currentAIText = ""
        ttftLatencyMs = nil
        isExpanded = true
        
        // Add user question bubble
        let userMessage = OverlayMessage(
            role: .user,
            text: prompt,
            isQuickActionLabel: isQuickAction,
            actionKind: actionKind,
            screenshotPreview: attachedImageBase64
        )
        messages.append(userMessage)
        
        // Add assistant placeholder
        let assistantMsgId = UUID().uuidString
        let assistantMessage = OverlayMessage(
            id: assistantMsgId,
            role: .assistant,
            text: "",
            isStreaming: true,
            providerName: currentModel.provider,
            modelName: currentModel.name
        )
        messages.append(assistantMessage)
        
        let meetingId = currentMeetingId ?? "standalone-\(UUID().uuidString)"
        self.currentMeetingId = meetingId
        let mode = activeMode
        let planner = turnPlanner
        let ocrContext = attachedOCRSnippet
        
        streamingTask = Task { [weak self] in
            let startTime = DispatchTime.now()
            var firstTokenRecorded = false
            
            if let planner {
                do {
                    let fullPrompt: String
                    if let ocr = ocrContext, !ocr.isEmpty {
                        fullPrompt = "\(prompt)\n\n[Screen Context]:\n\(ocr)"
                    } else {
                        fullPrompt = prompt
                    }
                    
                    // Build dynamic fallback ladder with user's selected model as primary rung
                    let chosen = self?.currentModel ?? Self.defaultModels[0]
                    var dynamicLadder: [FallbackRung] = [
                        FallbackRung(
                            providerType: chosen.providerType,
                            model: chosen.id,
                            ttftTimeoutSeconds: 4.5
                        )
                    ]
                    
                    // If Gemini selected, include sibling flash model as immediate second rung
                    if chosen.providerType == .googleGemini {
                        let backupModel = (chosen.id == "gemini-3.5-flash-lite") ? "gemini-3.8-flash" : "gemini-3.5-flash-lite"
                        dynamicLadder.append(FallbackRung(providerType: .googleGemini, model: backupModel, ttftTimeoutSeconds: 4.5))
                    }
                    
                    for rung in FallbackLadderEngine.defaultLadder {
                        if rung.providerType != chosen.providerType {
                            dynamicLadder.append(rung)
                        }
                    }
                    
                    let result = try await planner.generateAnswer(
                        question: fullPrompt,
                        meetingId: meetingId,
                        modeId: mode.id,
                        screenContext: nil,
                        customLadder: dynamicLadder
                    )
                    
                    await MainActor.run {
                        self?.currentProviderName = "\(result.providerUsed.rawValue.capitalized) (\(result.modelUsed))"
                        self?.updateAssistantMessage(id: assistantMsgId, provider: result.providerUsed.rawValue.capitalized, model: result.modelUsed)
                    }
                    
                    for try await chunk in result.stream {
                        if !firstTokenRecorded {
                            firstTokenRecorded = true
                            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
                            await MainActor.run {
                                self?.ttftLatencyMs = elapsed
                                self?.setAssistantLatency(id: assistantMsgId, latencyMs: elapsed)
                            }
                        }
                        await MainActor.run {
                            self?.currentAIText.append(chunk)
                            self?.appendAssistantChunk(id: assistantMsgId, chunk: chunk)
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errDescription: String
                        if let aiErr = error as? AIClientError {
                            switch aiErr {
                            case .missingAPIKey(let provider):
                                errDescription = "No API key configured for \(provider). Please set your API key in Settings (Cmd+,) or check your environment variables."
                            case .httpError(let statusCode, let body):
                                errDescription = "Provider returned HTTP \(statusCode): \(body)"
                            case .invalidURL(let url):
                                errDescription = "Invalid request URL: \(url)"
                            case .timeout(let msg):
                                errDescription = "Request timed out: \(msg)"
                            case .emptyResponse:
                                errDescription = "The model returned an empty response. Please verify that your API key is valid and has access to this model."
                            case .decodingError(let msg):
                                errDescription = "Failed to parse provider response: \(msg)"
                            }
                        } else {
                            errDescription = error.localizedDescription
                        }
                        let errText = "\n\n⚠️ **Error:** \(errDescription)"
                        self?.currentAIText.append(errText)
                        self?.appendAssistantChunk(id: assistantMsgId, chunk: errText)
                    }
                }
            } else {
                // Standalone test/simulation stream
                let simulatedChunks = [
                    "**BLUF**: For this problem, we can achieve **\(LaTeXMathFormatter.formatLaTeX(#"O(N \log N)"#))** time and **\(LaTeXMathFormatter.formatLaTeX(#"O(1)"#))** space.\n\n",
                    "### Optimal Approach\n",
                    "We use a two-pointer sliding window algorithm:\n\n",
                    "```python\ndef solve(nums: list[int]) -> int:\n    left = 0\n    max_len = 0\n    for right in range(len(nums)):\n        # check condition\n        max_len = max(max_len, right - left + 1)\n    return max_len\n```\n\n",
                    "The time complexity is $O(N)$ because each element is visited at most twice."
                ]
                
                for chunk in simulatedChunks {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                    if !firstTokenRecorded {
                        firstTokenRecorded = true
                        self?.ttftLatencyMs = 20.0
                        self?.setAssistantLatency(id: assistantMsgId, latencyMs: 20.0)
                    }
                    self?.currentAIText.append(chunk)
                    self?.appendAssistantChunk(id: assistantMsgId, chunk: chunk)
                }
            }
            
            await MainActor.run {
                self?.isAIStreaming = false
                self?.finalizeAssistantMessage(id: assistantMsgId)
            }
        }
    }
    
    private func updateAssistantMessage(id: String, provider: String, model: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].providerName = provider
            messages[idx].modelName = model
        }
    }
    
    private func setAssistantLatency(id: String, latencyMs: Double) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].latencyMs = latencyMs
        }
    }
    
    private func appendAssistantChunk(id: String, chunk: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].text.append(chunk)
        }
    }
    
    private func finalizeAssistantMessage(id: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
        }
    }
    
    /// Triggers one of the quick action presets (Cmd+1 to Cmd+7).
    public func triggerQuickAction(presetNumber: Int) {
        let presetPrompt: String
        let actionKind: String
        switch presetNumber {
        case 1:
            presetPrompt = "What should I say?"
            actionKind = "what_to_say"
        case 2:
            presetPrompt = "Clarify"
            actionKind = "clarify"
        case 3:
            presetPrompt = "Recap"
            actionKind = "recap"
        case 4:
            presetPrompt = "Follow-up questions"
            actionKind = "follow_up_questions"
        case 5:
            presetPrompt = "Full Solution"
            actionKind = "full_solution"
        case 6:
            presetPrompt = "Code hint"
            actionKind = "code_hint"
        case 7:
            presetPrompt = "Brainstorm"
            actionKind = "brainstorm"
        default:
            presetPrompt = "Help with the current question."
            actionKind = "general"
        }
        askAI(prompt: presetPrompt, isQuickAction: true, actionKind: actionKind)
    }
    
    /// Clears the session messages and in-flight responses.
    public func clearSession() {
        streamingTask?.cancel()
        isAIStreaming = false
        currentAIText = ""
        messages.removeAll()
        transcripts.removeAll()
        attachedOCRSnippet = nil
        attachedImageBase64 = nil
        attachedWebContext = nil
        ttftLatencyMs = nil
    }
}
