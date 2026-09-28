# Phase 2 Implementation Plan: ScreenCaptureKit Vision, Neural Engine OCR & Interactive Cropper

> [!IMPORTANT]
> **Status: Ready for Execution**
> This phase replaces the legacy Electron `desktopCapturer` (800ms–1800ms, multi-display DPI coordinate bugs, unhandled TCC race conditions, and heavy Tesseract fallback) with a sub-30ms hardware-accelerated pipeline built on `ScreenCaptureKit`, `Vision.framework`, and a native Cocoa `NSPanel` Interactive Cropper with Loupe magnification.

---

## 1. Architectural Architecture & Modules

```
┌────────────────────────────────────────────────────────────────────────┐
│                      NativelyVision Module                             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   ┌────────────────────────┐         ┌─────────────────────────────┐   │
│   │  ScreenCaptureService  │         │   InteractiveCropperPanel   │   │
│   │  (ScreenCaptureKit)    │◄───────┤ (NSPanel, sharingType=.none)│   │
│   │  - SCScreenshotManager │         │ - Multi-display canvas      │   │
│   │  - SCShareableContent  │         │ - Crosshair + Magnifier     │   │
│   │  - High-DPI crop math  │         │ - Dimension HUD             │   │
│   └───────────┬────────────┘         └─────────────────────────────┘   │
│               │ CGImage                                                │
│               ▼                                                        │
│   ┌────────────────────────┐         ┌─────────────────────────────┐   │
│   │   VisionOCRService     │         │   ScreenVisionCoordinator   │   │
│   │   (Apple Vision / ANE) │────────►│ - Combines capture + OCR    │   │
│   │   - VNRecognizeText    │         │ - SHA-256 deduplication     │   │
│   │   - Fast/Accurate mode │         │ - Prepared multimodal LLM   │   │
│   │   - Code/Text blocks   │         │   payload (image + context) │   │
│   └────────────────────────┘         └─────────────────────────────┘   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Detailed Technical Design

### 2.1 `ScreenCaptureService` (ScreenCaptureKit)
- **API**: Uses modern macOS `SCScreenshotManager.captureImage(contentFilter:configuration:)`.
- **Latency**: Sub-15ms on Apple Silicon unified memory.
- **Filtering**: Automatically excludes Natively's own overlay and cropper windows from captures.
- **Multi-Monitor Coordinate Conversion**:
  - Handles Apple's flipped Cocoa coordinates (bottom-left origin) vs CoreGraphics display coordinates (top-left origin).
  - Handles Retina scale factors (1x, 2x, 3x) without distortion or drift.
- **Image Processing**:
  - Direct CoreGraphics cropping (`cgImage.cropping(to:)`).
  - PNG and JPEG compression using `CGImageDestination` or `NSBitmapImageRep`.
  - Base64 encoding for direct LLM multimodal ingestion.

### 2.2 `VisionOCRService` (Apple Vision Framework)
- **Engine**: `VNRecognizeTextRequest` running on the Apple Neural Engine (`usesCPUOnly = false`).
- **Performance**: Sub-30ms text extraction for typical screen regions.
- **Models & Output**:
  - `recognitionLevel = .accurate` (or `.fast` for rapid continuous scanning).
  - Language detection with automatic multilingual support.
  - Normalizes Vision's unit coordinate space `[0, 1]` (origin bottom-left) to pixel/point space.
  - Extracts full text, paragraph blocks, and individual lines with confidence scores.

### 2.3 `InteractiveCropperPanel` (Native Cocoa NSPanel + Loupe)
- **Stealth Guarantee**: `sharingType = .none` ensures the cropper, guide lines, selection box, and magnifier loupe are 100% invisible on Zoom, Google Meet, Microsoft Teams, and ScreenCaptureKit recordings.
- **Window Level**: `.screenSaver` / `.popUpMenu` with `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, ensuring it renders seamlessly over fullscreen spaces without flipping activation policy or duplicating Dock icons.
- **Magnifier / Loupe**:
  - Real-time 2x–4x magnification around the cursor.
  - Pixel grid overlay showing individual display pixels for sharp alignment on code or UI elements.
  - Center crosshairs for single-pixel precision.
- **HUD Readout**: Displays selection dimensions (`W × H`) and keyboard hints (`Esc` to cancel, `Enter`/release to confirm).

### 2.4 `ScreenVisionCoordinator`
- Bridges capture, cropping, OCR, and storage.
- Implements SHA-256 image fingerprinting to prevent redundant OCR passes on unchanged screens.
- Generates `ScreenContext` ready for `NativelyAI` streaming prompts.

---

## 3. Implementation Steps

1. **Update `Package.swift`**:
   - Add `NativelyVision` library and target.
   - Add `NativelyVisionTests` test target.
2. **Implement Core Models**:
   - `ScreenRegion.swift`: Defines full screen, window, or arbitrary rectangle selections.
   - `OCRResult.swift`: Models extracted text, confidence, and line bounding boxes.
   - `ScreenContext.swift`: Bundles captured image, format, OCR text, and metadata.
3. **Implement `ScreenCaptureService.swift`**:
   - ScreenCaptureKit permission check and display capture.
   - CoreGraphics image crop and compression helpers.
4. **Implement `VisionOCRService.swift`**:
   - Apple Vision framework text recognition on Neural Engine.
5. **Implement `InteractiveCropperPanel.swift`**:
   - Custom `NSPanel` + `NSView` drawing selection rectangle, dimming mask, dimension HUD, and Loupe magnifier.
6. **Implement `ScreenVisionCoordinator.swift`**:
   - Orchestrates screenshot capture + interactive crop + OCR.
7. **Write Unit and Pipeline Tests (`NativelyVisionTests`)**:
   - Test coordinate transforms (Cocoa $\leftrightarrow$ CoreGraphics).
   - Test CoreGraphics image cropping and compression.
   - Test Vision OCR on synthetic rendered text (CoreText).
   - Test SHA-256 image hashing and deduplication.
8. **Verify & Local Commit**:
   - Run `swift test` across all packages.
   - Commit with `feat(vision): implement ScreenCaptureKit capture, Vision OCR, and interactive cropper`.
