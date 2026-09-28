# Phase 5: Launcher Dashboard, Companion Server & RAG Plan

## 1. Executive Summary & Objective

In the legacy Electron application:
- The Launcher UI was a massive, 1,300-line React component (`Launcher.tsx`) bound to heavy Node.js IPC channels (`ipcRenderer` / `ipcMain`), suffering from sluggish startup, memory hogging (~600MB idle), and window resizing lag.
- The companion server (`PhoneMirrorService.ts`) pulled in heavy npm modules (`http`, `ws`, `qrcode`), adding Node server overhead and socket race conditions.
- Vector retrieval and RAG involved complex spawned child processes (`resolveRagWorker.ts`, onnx workers, multi-stage reranker daemons) with high memory consumption and frequent IPC serialization bottlenecks.

In **Phase 5**, we replace these with native Swift 6 engines:
1. **`NativelyLauncher` (SwiftUI & AppKit)**:
   - Modern macOS Sequoia aesthetic: sleek split-view dashboard, liquid glass controls, instant launch (< 0.2s).
   - Meeting history viewer: search, date grouping (Today, Yesterday, Previous), duration, and status.
   - Deep meeting inspect view: BLUF summary, action items, key points, diarized transcript replay ("You" vs "Interviewer"), and recorded AI interactions.
   - Native Settings pane: API key management in macOS Keychain, custom Mode editor, audio input/output routing.
2. **`NativelyCompanion` (`Network.framework`)**:
   - Zero-dependency local micro-server built with Apple's `Network.framework` (`NWListener`):
     - Port 4123 with port fallback probing.
     - `GET /healthz`: Health status endpoint.
     - `POST /pair`: Extension token pairing.
     - `POST /dom`: Receives web DOM/text context from the Chrome extension.
     - `WebSocket /ws`: Real-time bidirectional streaming for phone mirroring and extension synchronization.
3. **`NativelyRAG` (Apple `Accelerate.framework`)**:
   - High-throughput vector search accelerated by Apple Silicon hardware (`vDSP_dotpr` cosine similarity across float arrays in sub-microsecond time).
   - Native SQLite chunk persistence via GRDB (`vector_chunks`).
   - `SemanticChunker` dividing conversation turns and notes into semantically coherent retrieval units.
   - `RAGRetriever` ranking by similarity, recency, and token budget.

---

## 2. Architecture & Component Blueprint

```mermaid
flowchart TD
    subgraph Browser & External Clients
        EXT["Natively Chrome Extension"]
        PH["Phone Mirror (Mobile Browser)"]
    end

    subgraph NativelyCompanion (Network.framework)
        NWL["NWListener (Port 4123)"]
        HROUT["HTTP Router (/healthz, /pair, /dom)"]
        WSH["WebSocket Handler (/ws)"]
    end

    subgraph NativelyRAG (Accelerate.framework)
        VSTOR["VectorStore (GRDB vector_chunks)"]
        VACC["Accelerate Vector Engine (vDSP Cosine Similarity)"]
        CHUNK["SemanticChunker"]
        RET["RAGRetriever (Similarity + Recency Re-ranking)"]
    end

    subgraph NativelyLauncher (SwiftUI & AppKit)
        LWIN["LauncherWindow (NSWindow)"]
        LVM["LauncherViewModel (@MainActor)"]
        MLIST["MeetingListView (Date groups, search, badges)"]
        MDETAIL["MeetingDetailView (BLUF, Action items, Transcripts)"]
        SETT["SettingsView (Keychain API keys, Modes, Companion)"]
    end

    subgraph Core Pipeline Services
        DB["AppDatabase (GRDB.swift)"]
        SEC["KeychainManager (macOS Keychain)"]
        AI["TurnPlannerActor & Models (NativelyAI)"]
    end

    EXT -->|POST /dom, /pair| HROUT
    EXT <-->|WebSocket /ws| WSH
    PH <-->|WebSocket /ws| WSH

    NWL --> HROUT
    NWL --> WSH
    HROUT --> LVM
    WSH --> LVM

    LVM --> DB
    LVM --> SEC
    LVM --> RET

    RET --> VACC
    RET --> VSTOR
    VSTOR --> DB
    CHUNK --> VSTOR

    LWIN --> LVM
    LVM --> MLIST
    LVM --> MDETAIL
    LVM --> SETT
```

---

## 3. Implementation Details

### 3.1 `NativelyCompanion` Engine
- **Server Core**:
  ```swift
  import Network
  public final class CompanionServer: Sendable {
      private let listener: NWListener
      public let port: UInt16
      // Handles HTTP /healthz, /pair, /dom and WebSocket /ws
  }
  ```
- **REST Endpoints**:
  - `GET /healthz` -> `{"ok": true, "version": "2.0.0-native", "activeMeeting": true/false}`
  - `POST /pair` -> Generates cryptographically secure pairing token stored in `KeychainManager`.
  - `POST /dom` -> Validates token, ingests active tab context (`title`, `url`, `text`), and passes to `OverlayViewModel` / `RAGRetriever`.
- **WebSocket Protocol**:
  - Outgoing events: `history`, `user`, `token`, `done`, `assistant`, `error`.
  - Incoming commands: `chat` (user prompt), `action` (trigger preset), `screenshot` (trigger crop).

### 3.2 `NativelyRAG` Engine
- **Hardware Acceleration**:
  - Uses `vDSP_dotpr` and `vDSP_svesq` from `Accelerate.framework` for instant SIMD dot product and Euclidean norm calculation:
    $$\text{similarity} = \frac{\mathbf{u} \cdot \mathbf{v}}{\|\mathbf{u}\|_2 \|\mathbf{v}\|_2}$$
  - Evaluates thousands of candidate chunks in < 2ms without python or node workers.
- **Vector Chunker**:
  - Splits meetings by transcript turns and speaker boundaries, ensuring context is not fragmented mid-sentence.
- **RAG Retriever**:
  - Hybrid scoring: $S = \alpha \cdot \text{CosineSimilarity} + (1 - \alpha) \cdot \text{RecencyFactor}$.
  - Token budget clamping (e.g. 1,500 tokens).

### 3.3 `NativelyLauncher` UI
- **Sidebar & Tabs**:
  - "Meetings" (Chronological meeting list with search and summary cards).
  - "Companion & Web" (QR code, pairing status, Chrome extension state).
  - "Settings" (API keys for Anthropic, OpenAI, Gemini, Groq, DeepSeek, custom system prompts).
- **Meeting Detail Screen**:
  - Executive BLUF Summary & Key Takeaways.
  - Action items checklist.
  - Diarized transcript viewer ("You" vs "Interviewer") with search and export to Markdown/PDF.
  - Recorded AI interactions timeline.

---

## 4. Verification & Testing Plan

1. **Unit & Pipeline Tests**:
   - `testCompanionServerHealthAndPairing`: Verifies HTTP request parsing and pairing response.
   - `testCompanionDOMContextIngestion`: Verifies `/dom` payload extraction and sanitization.
   - `testAccelerateVectorCosineSimilarity`: Compares SIMD `vDSP` dot product with scalar reference implementation.
   - `testSemanticChunkingAndRetrieval`: Tests chunking conversation turns and top-K candidate extraction.
   - `testLauncherViewModelState`: Validates meeting search, filtering, and detail loading from `AppDatabase`.
2. **End-to-End Build**:
   - Compile all packages and verify zero regressions across entire suite (`swift test`).
