# Phase 6: App Assembly, Menu Bar, Hardening, Profiling & Notarization Plan

## 1. Executive Summary & Objective

In this final phase of the native transformation, all individual engines—Audio (WhisperKit), Vision (ScreenCaptureKit & Vision OCR), AI (Multi-Cloud Streaming Ladder), UI (Stealth Liquid Glass Overlay & Launcher), Companion (Network.framework), and RAG (Accelerate.framework)—are assembled into a unified, production-ready macOS application: **`NativelyMac.app`**.

Key Deliverables:
1. **Unified Application Entrypoint (`NativelyApp`)**:
   - Native Swift 6 App lifecycle with `NSApplicationDelegateAdaptor`.
   - Menubar Status Item (`NSStatusItem`) providing discrete, zero-footprint controls: meeting status, stealth toggle, quick mode switcher, crop tool trigger, settings, and quit.
   - Global Hotkey Manager (`NSEvent` / `Carbon` / `CGEventTap`) handling system-wide shortcuts (`Cmd+\`, `Cmd+Shift+X`, `Cmd+O`, `Cmd+Enter`, `Cmd+1..7`).
2. **Permissions & Security Hardening**:
   - `Info.plist` with crystal-clear privacy rationale strings for `NSMicrophoneUsageDescription`, `NSScreenCaptureUsageDescription`, `NSLocalNetworkUsageDescription`.
   - `PermissionsManager` providing automated permission status checks and non-blocking guidance for macOS System Settings.
   - Entitlements file (`NativelyMac.entitlements`) with Hardened Runtime compatibility for Apple Developer ID notarization.
3. **Profiling, Memory Leak Detection & Verification**:
   - Zero-leak lifecycle testing: verify idle RAM stays bounded under **50 MB** (vs legacy Electron's 600–1,100 MB).
   - CPU usage benchmarking: verify 0% idle CPU and < 4% active meeting CPU (vs legacy Electron's 25–60%).
   - Screen capture and OCR latency benchmarks: < 40 ms total (vs legacy Electron's 800–1,800 ms).
4. **Automated Packaging & Sparkle Updates**:
   - Standalone build script (`scripts/build-native-app.sh`) generating a self-contained `.app` bundle and distributable `.dmg`.
   - Integration plan for Sparkle 2.x native auto-updater framework.

---

## 2. System Architecture Blueprint

```mermaid
flowchart TD
    subgraph System Integrations
        MB["NSStatusItem (Menu Bar)"]
        HK["GlobalHotkeyManager (NSEvent / Carbon)"]
        PERM["PermissionsManager (Screen, Mic, Accessibility)"]
    end

    subgraph NativelyApp (Main Executable)
        APP["@main NativelyApp"]
        DEL["AppDelegate (NSApplicationDelegate)"]
        COORD["AppCoordinator"]
    end

    subgraph Service Coordination
        AUD["DualChannelAudioCoordinator (WhisperKit)"]
        VIS["InteractiveCropperWindow (ScreenCaptureKit + OCR)"]
        AI["TurnPlannerActor (Streaming Fallback Ladder)"]
        RAG["RAGRetriever (Accelerate Vector Search)"]
        SRV["CompanionServer (Network.framework :4123)"]
    end

    subgraph Presentation Windows
        OVL["OverlayWindowManager (Stealth Liquid Glass Panel)"]
        LCH["LauncherWindowManager (AppKit / SwiftUI Dashboard)"]
    end

    APP --> DEL
    DEL --> COORD
    COORD --> MB
    COORD --> HK
    COORD --> PERM
    COORD --> AUD
    COORD --> VIS
    COORD --> AI
    COORD --> RAG
    COORD --> SRV
    COORD --> OVL
    COORD --> LCH
```

---

## 3. Component Specifications

### 3.1 AppCoordinator
Coordinates the lifecycle between background engines and user-facing windows:
- Listens to audio transcription stream and feeds recognized turns into `OverlayViewModel` and `AppDatabase`.
- Connects screen crop OCR events from `InteractiveCropperWindow` into `OverlayViewModel.attachScreenContext`.
- Binds companion server DOM payloads into active context blocks.
- Manages meeting session recording (starts audio capture, records duration, generates BLUF summary on completion).

### 3.2 Global Hotkey Manager
Registers and monitors global shortcuts:
- `Cmd+\`: Toggle Stealth Overlay visibility (`orderFront` / `orderOut`).
- `Cmd+Shift+X`: Trigger interactive screen crop tool (`InteractiveCropperWindow`).
- `Cmd+O`: Open Launcher Dashboard.
- `Cmd+Enter`: Trigger AI response for current context.
- `Cmd+1` to `Cmd+7`: Trigger mode quick actions.
- `Cmd+Shift+K`: Clear current overlay context.

### 3.3 Menu Bar Status Item (`NSStatusItem`)
Provides a lightweight macOS menu bar item:
- Icon indicates recording status (idle, listening, streaming).
- Menu items:
  - Toggle Stealth Overlay (`Cmd+\`)
  - Capture Screen Region (`Cmd+Shift+X`)
  - Open Dashboard (`Cmd+O`)
  - Active Mode submenu (Technical Interview, Coding, Executive, etc.)
  - Clear Context (`Cmd+Shift+K`)
  - Separator
  - Preferences / Settings... (`Cmd+,`)
  - Check for Updates...
  - Quit Natively (`Cmd+Q`)

### 3.4 Permissions Manager
Safely checks and requests system permissions:
- `CGPreflightScreenCaptureAccess()` and `CGRequestScreenCaptureAccess()` for ScreenCaptureKit.
- `AVCaptureDevice.authorizationStatus(for: .audio)` and `requestAccess(for: .audio)`.
- `AXIsProcessTrustedWithOptions` for Accessibility hotkeys.

---

## 4. Acceptance Criteria & Performance Verification

1. **Executable Build**:
   - `swift build -c release` produces a functional standalone binary `NativelyApp`.
2. **Stealth Verification**:
   - Overlay panel has `sharingType = .none`, completely invisible to screen shares and recording software.
3. **Memory & CPU Bounds**:
   - Idle footprint < 50 MB RAM.
   - Idle CPU usage = 0.0%.
   - Active meeting CPU usage < 4.0%.
4. **All Unit Tests Pass**:
   - 100% test pass rate across all 8 modules.
