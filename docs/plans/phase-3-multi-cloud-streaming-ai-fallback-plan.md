# Phase 3 Implementation Plan: Multi-Cloud Streaming AI & Fallback Ladder

> [!IMPORTANT]
> **Status: Ready for Execution**
> This phase implements the high-performance AI engine for Natively. It replaces Electron's multi-hop IPC streaming, WebView re-rendering, and heavy Node SDK dependencies with zero-dependency native Swift streaming actors (`URLSession.bytes`), a Time-to-First-Token (TTFT) 4.0-second failover watchdog ladder, and specialized prompt compilers for Technical Interviews, Negotiation, and Sales.

---

## 1. System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        NativelyAI Module                               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                     TurnPlannerActor                           │   │
│   │  - Gathers recent audio transcript turns & OCR screen context   │   │
│   │  - Resolves API keys from KeychainManager                      │   │
│   │  - Assembles prompt via ModePromptBuilder                      │   │
│   └───────────────────────────────┬────────────────────────────────┘   │
│                                   │                                    │
│                                   ▼                                    │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                   FallbackLadderEngine                         │   │
│   │  - TTFT Watchdog (4.0s timeout before first token)             │   │
│   │  - Commit Point Pattern (Silent failover before token 1)       │   │
│   │  - Circuit breaker (401/429 cooldowns & health tracking)       │   │
│   └───────────────┬───────────────────────────────┬────────────────┘   │
│                   │                               │                    │
│         ┌─────────┴─────────┐           ┌─────────┴─────────┐          │
│         ▼                   ▼           ▼                   ▼          │
│   ┌───────────┐       ┌───────────┐┌───────────┐      ┌───────────┐    │
│   │ Anthropic │       │  OpenAI   ││  Gemini   │      │  Ollama   │    │
│   │ (Claude   │       │  (GPT-4o/ ││ (1.5 Flash│      │ (Local    │    │
│   │  Sonnet)  │       │   Groq/   ││   & Pro)  │      │  Qwen /   │    │
│   │           │       │ DeepSeek) ││           │      │  Llama)   │    │
│   └───────────┘       └───────────┘└───────────┘      └───────────┘    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Capabilities & Design

### 2.1 Multi-Cloud Streaming Protocols
- **Anthropic Client**:
  - Endpoint: `https://api.anthropic.com/v1/messages`
  - Headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`.
  - SSE Events: Parses `content_block_delta` containing `delta.text`.
  - Multimodal Vision: Accepts base64 image media blocks (`type: "image"`, `source: { type: "base64", ... }`).
- **OpenAI-Compatible Client**:
  - Unified client supporting OpenAI (`api.openai.com/v1`), Groq (`api.groq.com/openai/v1`), and DeepSeek (`api.deepseek.com`).
  - Endpoint: `/chat/completions` with `stream: true`.
  - SSE Events: `data: {"choices": [{"delta": {"content": "..."}}]}`.
- **Google Gemini Client**:
  - Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse&key={apiKey}`.
  - SSE Events: `data: {"candidates": [{"content": {"parts": [{"text": "..."}]}}]}`.
- **Local Ollama Client**:
  - Endpoint: `http://127.0.0.1:11434/api/chat` with NDJSON streaming chunks (`{"message": {"content": "..."}}`).

### 2.2 Time-to-First-Token (TTFT) Watchdog & Commit Point Pattern
- **TTFT Watchdog**:
  - If token #1 does not arrive within **4.0 seconds**, the current stream is cancelled immediately.
  - Failover steps to the next configured provider rung on the ladder (e.g., Claude 3.5 Sonnet $\to$ GPT-4o $\to$ Groq Llama 3.3 $\to$ Gemini Flash).
- **Commit Point**:
  - Before the first token is emitted, all errors, 429s, and timeouts failover invisibly to the user.
  - Once the first token is yielded, the UI is committed to that provider and chunks stream smoothly at 120 FPS.

### 2.3 Mode Prompt Compiler
- **Technical Interview Mode**:
  - LeetCode / DSA / System Design framing.
  - Coding contract: Provides concise algorithmic intuition first, then optimized implementation ($O(N)$ time / space complexity), without unnecessary preamble.
  - Screen vision integration: analyzes code editor / problem description screenshots.
- **Negotiation Mode**:
  - Tactical empathy, calibrated questions, anchor discovery, objection diffusion.
- **Sales Mode**:
  - MEDDPICC/BANT qualification, pain identification, value-metric framing.
- **Executive Mode**:
  - High-signal executive summary, trade-offs, and decisive action items.

---

## 3. Implementation Plan
1. Update `Package.swift` to add `NativelyAI` target and `NativelyAITests`.
2. Implement Provider Models (`AIProvider.swift`, `AIRequest.swift`, `AIMessage.swift`).
3. Implement Streaming HTTP/SSE Parser (`SSEParser.swift`).
4. Implement Clients:
   - `AnthropicStreamingClient.swift`
   - `OpenAICompatibleStreamingClient.swift`
   - `GeminiStreamingClient.swift`
   - `OllamaStreamingClient.swift`
5. Implement `FallbackLadderEngine.swift` (TTFT watchdog + circuit breaker + commit point).
6. Implement `ModePromptBuilder.swift` (Technical, Negotiation, Sales, Executive).
7. Implement `TurnPlannerActor.swift` (Tying audio transcripts, screen OCR, keychain keys, and streaming).
8. Write comprehensive unit tests in `NativelyAITests` using deterministic mock HTTP streams and synthetic prompts.
9. Verify all package tests compile and pass.
10. Commit Phase 3 locally.
