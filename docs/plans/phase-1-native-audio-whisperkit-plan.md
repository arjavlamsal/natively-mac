# Phase 1 Implementation Plan: Native Audio Engine & WhisperKit STT

> [!IMPORTANT]
> **Objective**: Replace the entire legacy audio stack (Rust `native-module` napi-rs, Node.js audio buffers, and child CLI helper processes) with a high-performance, pure Swift audio capture and speech-to-text pipeline running directly on Apple Silicon.

---

## 1. Architecture Overview

```
PHASE 1 NATIVE AUDIO & TRANSCRIPTION PIPELINE

┌─────────────────────────┐          ┌─────────────────────────┐
│     Microphone In       │          │   System Audio Loopback │
│    (AVAudioEngine)      │          │    (ScreenCaptureKit)   │
└────────────┬────────────┘          └────────────┬────────────┘
             │                                    │
             ▼                                    ▼
┌─────────────────────────┐          ┌─────────────────────────┐
│  AudioResampler (16kHz) │          │  AudioResampler (16kHz) │
│    Channel: "You"       │          │  Channel: "Interviewer" │
└────────────┬────────────┘          └────────────┬────────────┘
             │                                    │
             ├─────────────────┬──────────────────┤
             │                 │                  │
             ▼                 ▼                  ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│ Voice Activity Detector │  │   DualChannelAudioCoordinator   │
│   (VAD / Energy Gate)   │  │   - Audio Route Interruption    │
└─────────────────────────┘  │     Resilience (AirPods Switch) │
                             └────────────────┬────────────────┘
                                              │
                                              ▼
                             ┌─────────────────────────────────┐
                             │    WhisperKit CoreML Engine     │
                             │   (Apple Neural Engine - ANE)   │
                             │  - Whisper Small / Base Model   │
                             └────────────────┬────────────────┘
                                              │
                                              ▼
                             ┌─────────────────────────────────┐
                             │ Timestamped Transcript Turns    │
                             │   ("You" vs "Interviewer")      │
                             │  -> Emits to NativelyDatabase   │
                             └─────────────────────────────────┘
```

---

## 2. Key Components to Build

### 2.1 Audio Resampling & Format Normalization (`AudioResampler.swift`)
- **Input**: Any hardware format (e.g. 44.1 kHz, 48 kHz, stereo, floating-point PCM).
- **Output**: Fixed uniform format required by Whisper: **16,000 Hz, 1-channel (mono), 16-bit linear PCM**.
- **Engine**: `AVAudioConverter` utilizing Apple's hardware-accelerated sample rate conversion.

### 2.2 Microphone Capture Service (`MicrophoneCaptureService.swift`)
- Uses `AVAudioEngine` with a tap installed on `inputNode`.
- Runs on a dedicated real-time audio queue.
- Emits chunks to the audio coordinator with speaker tag `"You"`.

### 2.3 System Audio Loopback Tap (`SystemAudioCaptureService.swift`)
- Uses macOS 15 `ScreenCaptureKit` audio capture:
  ```swift
  let config = SCStreamConfiguration()
  config.capturesAudio = true
  config.sampleRate = 16000
  config.channelCount = 1
  ```
- Excludes Natively's own overlay windows from capture using `SCContentFilter(display:excludingWindows:)`.
- Emits chunks to the audio coordinator with speaker tag `"Interviewer"` (or remote participant).

### 2.4 Audio Route Interruption Resilience (`AudioRouteObserver.swift`)
- Observes `NotificationCenter.default` for `AVAudioEngineConfigurationChange`.
- Observes Core Audio property listeners for default input/output hardware device switching.
- **Behavior**: If the user connects or disconnects AirPods mid-meeting, the engine pauses, resets the tap on the new device, and resumes capture in < 150 ms without dropping the active meeting session or throwing unhandled errors.

### 2.5 Voice Activity Detection (`VoiceActivityDetector.swift`)
- Dual-mode VAD:
  - Energy/RMS zero-crossing rate detector for low-latency voice boundary identification.
  - End-of-turn silences prevent sending dead air to WhisperKit, conserving Apple Neural Engine power.

### 2.6 WhisperKit CoreML Engine (`WhisperTranscriptionService.swift`)
- **Dependency**: `WhisperKit` (`https://github.com/argmaxinc/WhisperKit.git`).
- Model: `openai_whisper-base` or `openai_whisper-small` quantized for Apple Neural Engine (ANE).
- Streaming transcription yielding real-time text segments with confidence scores and timestamps.

### 2.7 Dual-Channel Audio Coordinator (`DualChannelAudioCoordinator.swift`)
- Coordinates the lifecycle of Microphone + System Audio streams.
- Reconciles overlapping turns and assigns speaker labels:
  - Mic audio $\to$ `"You"`
  - System audio $\to$ `"Interviewer"`
- Persists final turns to `AppDatabase` via `saveTranscriptTurn(_:)`.

---

## 3. Step-by-Step Execution Plan

| Step | Action | Files Affected | Verification Criteria |
| :--- | :--- | :--- | :--- |
| **Step 1** | Update `Package.swift` to add `WhisperKit` dependency and declare `NativelyAudio` target + test target. | `macos/Package.swift` | `swift package resolve` completes successfully. |
| **Step 2** | Implement `AudioResampler` using `AVAudioConverter` to convert arbitrary audio buffers to 16kHz mono PCM. | `macos/Sources/NativelyAudio/AudioResampler.swift` | Unit tests verify 48kHz $\to$ 16kHz buffer conversion. |
| **Step 3** | Implement `MicrophoneCaptureService` wrapping `AVAudioEngine.inputNode`. | `macos/Sources/NativelyAudio/MicrophoneCaptureService.swift` | Captures mic frames with volume meter readings. |
| **Step 4** | Implement `SystemAudioCaptureService` using `ScreenCaptureKit`. | `macos/Sources/NativelyAudio/SystemAudioCaptureService.swift` | Compiles against macOS 15 SCK APIs with exclusion filters. |
| **Step 5** | Implement `AudioRouteObserver` for dynamic hardware device switching. | `macos/Sources/NativelyAudio/AudioRouteObserver.swift` | Unit tests verify configuration change notifications. |
| **Step 6** | Implement `VoiceActivityDetector` for speech silence gating. | `macos/Sources/NativelyAudio/VoiceActivityDetector.swift` | Distinguishes silence vs speech buffer frames. |
| **Step 7** | Implement `WhisperTranscriptionService` integrating `WhisperKit`. | `macos/Sources/NativelyAudio/WhisperTranscriptionService.swift` | Model loads on ANE and processes test WAV buffer. |
| **Step 8** | Implement `DualChannelAudioCoordinator` linking Mic + System streams to Whisper and emitting `TranscriptTurn` items. | `macos/Sources/NativelyAudio/DualChannelAudioCoordinator.swift` | Full dual-stream simulation emits synchronized transcript turns. |
| **Step 9** | Create comprehensive test suite in `Tests/NativelyAudioTests/`. | `macos/Tests/NativelyAudioTests/*` | `swift test` passes with 100% green tests. |

---

## 4. Performance & Memory Budget for Phase 1

- **Idle RAM**: < 20 MB.
- **Active Transcription RAM**: 60 MB – 120 MB (inclusive of WhisperKit CoreML model weights mapped in unified memory).
- **CPU Utilization during 2-channel recording**: 1% – 4% (Whisper inference offloaded to Apple Neural Engine).
- **Latency**: Sub-300ms audio-to-text latency.
