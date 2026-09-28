import SwiftUI
import Combine
import NativelyCore
import NativelyDatabase
import NativelyAudio
import NativelyVision
import NativelyAI

/// View model driving the stealth overlay UI and bridging audio, vision, AI, and persistence.
@MainActor
public final class OverlayViewModel: ObservableObject {
    
    // UI State
    @Published public var isExpanded: Bool = true
    @Published public var isPassthrough: Bool = false
    @Published public var isFocusingPrompt: Bool = false
    @Published public var quickPromptText: String = ""
    
    // Audio Activity
    @Published public var isAudioActive: Bool = false
    @Published public var micRMS: Float = 0.0
    @Published public var systemRMS: Float = 0.0
    
    // Transcripts
    @Published public var transcripts: [TranscriptTurn] = []
    
    // Mode
    @Published public var activeMode: Mode
    @Published public var availableModes: [Mode] = []
    
    // AI Streaming State
    @Published public var isAIStreaming: Bool = false
    @Published public var currentAIText: String = ""
    @Published public var currentProviderName: String = "Claude 3.5 Sonnet"
    @Published public var ttftLatencyMs: Double? = nil
    
    // Vision / Screen Context
    @Published public var attachedOCRSnippet: String? = nil
    @Published public var attachedImageBase64: String? = nil
    
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
    
    /// Submits a question/prompt to the streaming AI engine.
    public func askAI(prompt: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        streamingTask?.cancel()
        isAIStreaming = true
        currentAIText = ""
        ttftLatencyMs = nil
        isExpanded = true
        
        let meetingId = currentMeetingId ?? "standalone-\(UUID().uuidString)"
        self.currentMeetingId = meetingId
        let mode = activeMode
        let planner = turnPlanner
        
        streamingTask = Task { [weak self] in
            let startTime = DispatchTime.now()
            var firstTokenRecorded = false
            
            if let planner {
                do {
                    let result = try await planner.generateAnswer(
                        question: prompt,
                        meetingId: meetingId,
                        modeId: mode.id,
                        screenContext: nil
                    )
                    
                    await MainActor.run {
                        self?.currentProviderName = "\(result.providerUsed.rawValue.capitalized) (\(result.modelUsed))"
                    }
                    
                    for try await chunk in result.stream {
                        if !firstTokenRecorded {
                            firstTokenRecorded = true
                            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
                            await MainActor.run {
                                self?.ttftLatencyMs = elapsed
                            }
                        }
                        await MainActor.run {
                            self?.currentAIText.append(chunk)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self?.currentAIText.append("\n\n*(Error: \(error.localizedDescription))*")
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
                    }
                    self?.currentAIText.append(chunk)
                }
            }
            
            await MainActor.run {
                self?.isAIStreaming = false
            }
        }
    }
    
    /// Triggers one of the quick action presets (Cmd+1 to Cmd+7).
    public func triggerQuickAction(presetNumber: Int) {
        let presetPrompt: String
        switch presetNumber {
        case 1:
            presetPrompt = "What should I answer right now? Provide a concise, high-impact BLUF response."
        case 2:
            presetPrompt = "Suggest 2-3 clarifying questions to ask the interviewer before diving into code."
        case 3:
            presetPrompt = "Recap the problem constraints, edge cases, and brainstorm 2 distinct approaches."
        case 4:
            presetPrompt = "Provide a strong follow-up point or optimization on the current solution."
        case 5:
            presetPrompt = "Provide the complete optimal solution with time/space complexity analysis."
        case 6:
            presetPrompt = "Give me a subtle code hint without giving away the full solution."
        case 7:
            presetPrompt = "Brainstorm architectural trade-offs and alternative data structures."
        default:
            presetPrompt = "Help with the current question."
        }
        askAI(prompt: presetPrompt)
    }
    
    /// Clears the session messages and in-flight responses.
    public func clearSession() {
        streamingTask?.cancel()
        isAIStreaming = false
        currentAIText = ""
        transcripts.removeAll()
        attachedOCRSnippet = nil
        attachedImageBase64 = nil
        ttftLatencyMs = nil
    }
}
