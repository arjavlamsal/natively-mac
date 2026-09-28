import Foundation
import NativelyCore

public struct FallbackRung: Sendable, Equatable {
    public let providerType: AIProviderType
    public let model: String
    public let ttftTimeoutSeconds: Double
    
    public init(
        providerType: AIProviderType,
        model: String? = nil,
        ttftTimeoutSeconds: Double = 4.0
    ) {
        self.providerType = providerType
        self.model = model ?? providerType.defaultModel
        self.ttftTimeoutSeconds = ttftTimeoutSeconds
    }
}

public struct FallbackResult: Sendable {
    public let stream: AsyncThrowingStream<String, Error>
    public let providerUsed: AIProviderType
    public let modelUsed: String
}

/// Actor orchestrating the multi-provider Time-to-First-Token (TTFT) fallback ladder and circuit breaker.
public actor FallbackLadderEngine {
    private var circuitBreakers: [AIProviderType: Date] = [:]
    private var consecutiveFailures: [AIProviderType: Int] = [:]
    
    public init() {}
    
    /// Default prioritized fallback ladder.
    public static var defaultLadder: [FallbackRung] {
        [
            FallbackRung(providerType: .anthropic, model: "claude-3-5-sonnet-20241022", ttftTimeoutSeconds: 4.0),
            FallbackRung(providerType: .openAI, model: "gpt-4o", ttftTimeoutSeconds: 4.0),
            FallbackRung(providerType: .groq, model: "llama-3.3-70b-versatile", ttftTimeoutSeconds: 3.0),
            FallbackRung(providerType: .googleGemini, model: "gemini-1.5-flash", ttftTimeoutSeconds: 3.5),
            FallbackRung(providerType: .deepSeek, model: "deepseek-chat", ttftTimeoutSeconds: 4.0),
            FallbackRung(providerType: .ollama, model: "llama3.2", ttftTimeoutSeconds: 5.0)
        ]
    }
    
    /// Checks if a provider's circuit breaker is open (tripped).
    public func isCircuitOpen(for provider: AIProviderType) -> Bool {
        if let cooldownUntil = circuitBreakers[provider] {
            if Date() < cooldownUntil {
                return true
            } else {
                circuitBreakers.removeValue(forKey: provider)
            }
        }
        return false
    }
    
    /// Records a success, resetting consecutive failures.
    public func recordSuccess(for provider: AIProviderType) {
        consecutiveFailures[provider] = 0
        circuitBreakers.removeValue(forKey: provider)
    }
    
    /// Records a failure, tripping the circuit if threshold is reached.
    public func recordFailure(for provider: AIProviderType, isAuthError: Bool = false) {
        let fails = (consecutiveFailures[provider] ?? 0) + 1
        consecutiveFailures[provider] = fails
        
        let cooldownDuration: TimeInterval = isAuthError ? 300.0 : (fails >= 2 ? 60.0 : 15.0)
        circuitBreakers[provider] = Date().addingTimeInterval(cooldownDuration)
    }
    
    /// Resets all circuit breakers and health states.
    public func resetAll() {
        circuitBreakers.removeAll()
        consecutiveFailures.removeAll()
    }
    
    /// Executes a request across the fallback ladder with TTFT watchdog and commit-point guarantees.
    public func executeStream(
        ladder: [FallbackRung],
        clientResolver: @Sendable (AIProviderType) -> StreamingAIProvider?,
        keyResolver: @Sendable (AIProviderType) async -> String?,
        baseRequest: (String) -> AIRequest
    ) async throws -> FallbackResult {
        var lastError: Error = AIClientError.emptyResponse
        
        for rung in ladder {
            if isCircuitOpen(for: rung.providerType) {
                continue
            }
            
            guard let client = clientResolver(rung.providerType) else {
                continue
            }
            
            let apiKey = await keyResolver(rung.providerType)
            if !rung.providerType.isLocal && (apiKey == nil || apiKey?.isEmpty == true) {
                // Skip cloud providers with no key configured
                continue
            }
            
            let request = baseRequest(rung.model)
            let rawStream = client.stream(request: request, apiKey: apiKey)
            
            let gate = StreamGate()
            
            let outputStream = AsyncThrowingStream<String, Error> { continuation in
                Task {
                    do {
                        for try await chunk in rawStream {
                            await gate.onChunk()
                            continuation.yield(chunk)
                        }
                        await gate.onFinish()
                        continuation.finish()
                    } catch {
                        await gate.onError(error)
                        continuation.finish(throwing: error)
                    }
                }
            }
            
            do {
                // Wait for the first token to arrive
                try await gate.waitForFirstToken(timeoutSeconds: rung.ttftTimeoutSeconds)
                
                // First token arrived before timeout! We are COMMITTED.
                recordSuccess(for: rung.providerType)
                return FallbackResult(
                    stream: outputStream,
                    providerUsed: rung.providerType,
                    modelUsed: rung.model
                )
            } catch {
                lastError = error
                let isAuth = (error as? AIClientError).map { err in
                    if case .httpError(let code, _) = err { return code == 401 || code == 403 }
                    if case .missingAPIKey = err { return true }
                    return false
                } ?? false
                recordFailure(for: rung.providerType, isAuthError: isAuth)
                // Proceed to next rung in ladder
            }
        }
        
        throw lastError
    }
}

/// Actor gating the commit-point between pre-token-1 failover and post-token-1 committed streaming.
private actor StreamGate {
    private var hasFirstChunk = false
    private var continuation: CheckedContinuation<Void, Error>?
    private var isTimedOut = false
    private var timeoutTask: Task<Void, Never>?
    
    init() {}
    
    func onChunk() {
        guard !hasFirstChunk && !isTimedOut else { return }
        hasFirstChunk = true
        timeoutTask?.cancel()
        continuation?.resume()
        continuation = nil
    }
    
    func onError(_ error: Error) {
        guard !hasFirstChunk && !isTimedOut else { return }
        timeoutTask?.cancel()
        continuation?.resume(throwing: error)
        continuation = nil
    }
    
    func onFinish() {
        guard !hasFirstChunk && !isTimedOut else { return }
        timeoutTask?.cancel()
        continuation?.resume(throwing: AIClientError.emptyResponse)
        continuation = nil
    }
    
    func handleTimeout() {
        guard !hasFirstChunk else { return }
        isTimedOut = true
        continuation?.resume(throwing: AIClientError.timeout("TTFT budget exceeded"))
        continuation = nil
    }
    
    func waitForFirstToken(timeoutSeconds: Double) async throws {
        if hasFirstChunk { return }
        if isTimedOut { throw AIClientError.timeout("TTFT budget exceeded") }
        
        self.timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            await self?.handleTimeout()
        }
        
        try await withCheckedThrowingContinuation { cont in
            if hasFirstChunk {
                cont.resume()
            } else if isTimedOut {
                cont.resume(throwing: AIClientError.timeout("TTFT budget exceeded"))
            } else {
                self.continuation = cont
            }
        }
    }
}
