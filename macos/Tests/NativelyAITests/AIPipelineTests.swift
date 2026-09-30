import Testing
import Foundation
import CoreGraphics
@testable import NativelyCore
@testable import NativelyDatabase
@testable import NativelySecurity
@testable import NativelyVision
@testable import NativelyAI

/// Mock streaming provider for deterministic testing of fallback ladder and timeouts
final class MockStreamingProvider: StreamingAIProvider, @unchecked Sendable {
    let providerType: AIProviderType
    let chunks: [String]
    let delayBeforeFirstChunk: TimeInterval
    let shouldFail: Bool
    let failureError: Error
    
    init(
        providerType: AIProviderType,
        chunks: [String] = ["Hello", " ", "World"],
        delayBeforeFirstChunk: TimeInterval = 0.0,
        shouldFail: Bool = false,
        failureError: Error = AIClientError.httpError(statusCode: 500, body: "Server Overloaded")
    ) {
        self.providerType = providerType
        self.chunks = chunks
        self.delayBeforeFirstChunk = delayBeforeFirstChunk
        self.shouldFail = shouldFail
        self.failureError = failureError
    }
    
    func stream(request: AIRequest, apiKey: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if delayBeforeFirstChunk > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delayBeforeFirstChunk * 1_000_000_000))
                }
                
                if shouldFail {
                    continuation.finish(throwing: failureError)
                    return
                }
                
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

@Suite("NativelyAI Pipeline Tests")
struct AIPipelineTests {
    
    @Test("SSEParser correctly extracts events and payloads")
    func testSSEParser() async throws {
        let rawSSELines = [
            "event: message",
            "data: {\"type\": \"content_block_delta\", \"delta\": {\"text\": \"Native\"}}",
            "",
            "data: {\"type\": \"content_block_delta\", \"delta\": {\"text\": \" Swift\"}}",
            "",
            "data: [DONE]"
        ]
        
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for line in rawSSELines {
            if let evt = parser.feed(line: line) {
                events.append(evt)
            }
        }
        if let trailing = parser.finish() {
            events.append(trailing)
        }
        
        #expect(events.count == 3)
        #expect(events[0].event == "message")
        #expect(events[0].data.contains("Native"))
        #expect(events[1].data.contains("Swift"))
        #expect(events[2].data == "[DONE]")
    }
    
    @Test("SSEParser handles continuous data frames without empty line delimiters (Gemini/OpenAI streaming)")
    func testSSEParserWithoutBlankLines() async throws {
        let continuousLines = [
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello!\"}]}}]}",
            "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \" How can I help?\"}]}}]}",
            "data: [DONE]"
        ]
        
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for line in continuousLines {
            if let evt = parser.feed(line: line) {
                events.append(evt)
            }
        }
        if let trailing = parser.finish() {
            events.append(trailing)
        }
        
        #expect(events.count == 3)
        #expect(events[0].data.contains("Hello!"))
        #expect(events[1].data.contains("How can I help?"))
        #expect(events[2].data == "[DONE]")
    }
    
    @Test("ModePromptBuilder generates targeted system prompts with screen OCR")
    func testModePromptBuilder() {
        let ocrResult = OCRResult(fullText: "class Solution { func twoSum() }")
        let dummyImage = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 40, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let screenContext = ScreenContext(
            cgImage: dummyImage,
            pngData: Data(),
            base64DataUrl: "data:image/png;base64,",
            ocrResult: ocrResult,
            bounds: .zero,
            imageHash: "hash"
        )
        
        let technicalPrompt = ModePromptBuilder.buildSystemPrompt(modeId: "technical", screenContext: screenContext)
        #expect(technicalPrompt.contains("technical interview copilot"))
        #expect(technicalPrompt.contains("Time Complexity"))
        #expect(technicalPrompt.contains("twoSum()"))
        
        let negotiationPrompt = ModePromptBuilder.buildSystemPrompt(modeId: "negotiation")
        #expect(negotiationPrompt.contains("negotiation coach"))
        #expect(negotiationPrompt.contains("tactical empathy"))
    }
    
    @Test("FallbackLadderEngine switches to fallback provider on primary failure")
    func testFallbackOnFailure() async throws {
        let engine = FallbackLadderEngine()
        
        // Primary fails with 500 error
        let failingPrimary = MockStreamingProvider(
            providerType: .anthropic,
            shouldFail: true,
            failureError: AIClientError.httpError(statusCode: 500, body: "Anthropic Outage")
        )
        
        // Fallback succeeds
        let successfulFallback = MockStreamingProvider(
            providerType: .openAI,
            chunks: ["Fallback", " ", "Succeeded"]
        )
        
        let ladder = [
            FallbackRung(providerType: .anthropic, ttftTimeoutSeconds: 2.0),
            FallbackRung(providerType: .openAI, ttftTimeoutSeconds: 2.0)
        ]
        
        let result = try await engine.executeStream(
            ladder: ladder,
            clientResolver: { provider in
                if provider == .anthropic { return failingPrimary }
                if provider == .openAI { return successfulFallback }
                return nil
            },
            keyResolver: { _ in "mock-key" },
            baseRequest: { model in AIRequest(model: model, messages: []) }
        )
        
        #expect(result.providerUsed == .openAI)
        
        var output = ""
        for try await chunk in result.stream {
            output += chunk
        }
        #expect(output == "Fallback Succeeded")
    }
    
    @Test("FallbackLadderEngine watchdog triggers failover on TTFT timeout")
    func testFallbackOnTTFTTimeout() async throws {
        let engine = FallbackLadderEngine()
        
        // Slow primary takes 0.5s, but budget is 0.1s
        let slowPrimary = MockStreamingProvider(
            providerType: .anthropic,
            chunks: ["Too Late"],
            delayBeforeFirstChunk: 0.5
        )
        
        // Fast fallback delivers immediately
        let fastFallback = MockStreamingProvider(
            providerType: .groq,
            chunks: ["Fast", " ", "Groq"]
        )
        
        let ladder = [
            FallbackRung(providerType: .anthropic, ttftTimeoutSeconds: 0.1),
            FallbackRung(providerType: .groq, ttftTimeoutSeconds: 1.0)
        ]
        
        let result = try await engine.executeStream(
            ladder: ladder,
            clientResolver: { provider in
                if provider == .anthropic { return slowPrimary }
                if provider == .groq { return fastFallback }
                return nil
            },
            keyResolver: { _ in "mock-key" },
            baseRequest: { model in AIRequest(model: model, messages: []) }
        )
        
        #expect(result.providerUsed == .groq)
        
        var output = ""
        for try await chunk in result.stream {
            output += chunk
        }
        #expect(output == "Fast Groq")
    }
    
    @Test("TurnPlannerActor end-to-end question answering and persistence")
    func testTurnPlannerEndToEnd() async throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "m-ai-test"
        try db.saveMeeting(Meeting(id: meetingId, title: "AI Test Meeting"))
        
        let mockClient = MockStreamingProvider(
            providerType: .openAI,
            chunks: ["Optimized ", "O(N) ", "solution"]
        )
        
        let customClients: [AIProviderType: StreamingAIProvider] = [
            .openAI: mockClient
        ]
        
        let testKeychain = KeychainManager(service: "test.planner.\(UUID().uuidString)")
        try await testKeychain.save(key: "openai_api_key", value: "sk-mock-test-key")
        
        let planner = TurnPlannerActor(
            database: db,
            keychain: testKeychain,
            customClients: customClients
        )
        
        let ladder = [FallbackRung(providerType: .openAI, ttftTimeoutSeconds: 2.0)]
        let result = try await planner.generateAnswer(
            question: "How to solve Two Sum?",
            meetingId: meetingId,
            modeId: "technical",
            customLadder: ladder
        )
        
        var answer = ""
        for try await chunk in result.stream {
            answer += chunk
        }
        
        #expect(answer == "Optimized O(N) solution")
        
        // Verify interaction was saved to database
        let savedInteractions = try db.fetchAIInteractions(for: meetingId)
        #expect(savedInteractions.count == 1)
        #expect(savedInteractions[0].userQuery == "How to solve Two Sum?")
        #expect(savedInteractions[0].aiResponse == "Optimized O(N) solution")
        #expect(savedInteractions[0].type == "answer")
    }
    
    @Test("FollowUpDraftGenerator produces tailored drafts for all tones and types")
    func testFollowUpDraftGenerator() {
        let summary = DetailedSummary(
            overview: "Architecture review of the native Swift Mac client.",
            actionItems: ["Finalize tests", "Build DMG package"],
            keyPoints: ["Replaced Electron with Swift 6 AppKit/SwiftUI", "Zero Electron runtime memory overhead"],
            decisions: [DecisionItem(text: "Use GRDB SQLite instead of Realm")]
        )
        let meeting = Meeting(
            id: "m-draft",
            title: "Mac Architecture Sync",
            summaryJson: String(data: try! JSONEncoder().encode(summary), encoding: .utf8)
        )
        
        // 1. Concise email
        let draftEmail = FollowUpDraftGenerator.generateDraft(meeting: meeting, modeId: "general", tone: .concise, draftType: .email)
        #expect(draftEmail.subject.contains("Follow-up:"))
        #expect(draftEmail.body.contains("Key Points Discussed:"))
        #expect(draftEmail.actionItems.count == 2)
        #expect(draftEmail.fullFormattedText.contains("Next Steps / Action Items:"))
        
        // 2. Formal interview feedback
        let draftInterview = FollowUpDraftGenerator.generateDraft(meeting: meeting, modeId: "technical-interview", tone: .formal, draftType: .interviewFeedback)
        #expect(draftInterview.subject.contains("Interview Notes"))
        #expect(draftInterview.greeting.contains("Hiring Team"))
        #expect(draftInterview.fullFormattedText.contains("Next Steps"))
        
        // 3. Friendly project update
        let draftUpdate = FollowUpDraftGenerator.generateDraft(meeting: meeting, modeId: "team-meet", tone: .friendly, draftType: .projectUpdate)
        #expect(draftUpdate.subject.contains("Project Update"))
        #expect(draftUpdate.body.contains("Decisions & Highlights:"))
        
        // 4. Study notes
        let draftNotes = FollowUpDraftGenerator.generateDraft(meeting: meeting, modeId: "lecture", tone: .casual, draftType: .studyNotes)
        #expect(draftNotes.subject.contains("Lecture & Discussion Notes"))
        #expect(draftNotes.greeting.contains("Summary Notes"))
    }
    
    @Test("ModePromptBuilder generates distinct tailored prompts for all 11 modes")
    func testAllElevenModesInPromptBuilder() {
        let allModes = [
            "technical-interview",
            "looking-for-work",
            "sales",
            "recruiting",
            "team-meet",
            "lecture",
            "seminar",
            "call-center",
            "negotiation",
            "executive",
            "general"
        ]
        
        for mode in allModes {
            let prompt = ModePromptBuilder.buildSystemPrompt(modeId: mode, screenContext: nil)
            #expect(!prompt.isEmpty)
            #expect(prompt.contains("You are Natively"))
        }
    }
    
    @Test("TurnPlannerActor attaches screenshot base64 images and generates answer")
    func testTurnPlannerScreenshotAttachment() async throws {
        let db = try AppDatabase.makeInMemory()
        let meetingId = "meeting-vision-test"
        try db.saveMeeting(Meeting(id: meetingId, title: "Vision Test Meeting"))
        
        let dummyImage = CGContext(
            data: nil,
            width: 10,
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 40,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!.makeImage()!
        
        let screen = ScreenContext(
            cgImage: dummyImage,
            pngData: Data([0x89, 0x50, 0x4E, 0x47]),
            base64DataUrl: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==",
            ocrResult: OCRResult(fullText: "LeetCode 1: Two Sum"),
            bounds: .zero,
            imageHash: "hash123"
        )
        
        let mockProvider = MockStreamingProvider(
            providerType: .googleGemini,
            chunks: ["The optimal solution is to use a Hash Map in $O(N)$ time."]
        )
        let customClients: [AIProviderType: StreamingAIProvider] = [
            .googleGemini: mockProvider
        ]
        
        let testKeychain = KeychainManager(service: "test.planner.vision.\(UUID().uuidString)")
        try await testKeychain.save(key: "gemini_api_key", value: "mock-gemini-key")
        
        let planner = TurnPlannerActor(
            database: db,
            keychain: testKeychain,
            customClients: customClients
        )
        
        let ladder = [FallbackRung(providerType: .googleGemini, model: "gemini-3.5-flash-lite")]
        let result = try await planner.generateAnswer(
            question: "How do I solve this?",
            meetingId: meetingId,
            modeId: "technical",
            screenContext: screen,
            base64Image: screen.base64DataUrl,
            customLadder: ladder
        )
        
        var answer = ""
        for try await chunk in result.stream {
            answer += chunk
        }
        #expect(answer.contains("Hash Map"))
        #expect(result.providerUsed == AIProviderType.googleGemini)
    }
}
