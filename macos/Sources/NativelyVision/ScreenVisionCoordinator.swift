import Foundation
import CoreGraphics
import AppKit

/// Bundles the captured screen raster, OCR text, base64 payload, and metadata.
public struct ScreenContext: Sendable {
    public let cgImage: CGImage
    public let pngData: Data
    public let base64DataUrl: String
    public let ocrResult: OCRResult
    public let bounds: CGRect
    public let imageHash: String
    public let timestamp: Date
    
    public init(
        cgImage: CGImage,
        pngData: Data,
        base64DataUrl: String,
        ocrResult: OCRResult,
        bounds: CGRect,
        imageHash: String,
        timestamp: Date = Date()
    ) {
        self.cgImage = cgImage
        self.pngData = pngData
        self.base64DataUrl = base64DataUrl
        self.ocrResult = ocrResult
        self.bounds = bounds
        self.imageHash = imageHash
        self.timestamp = timestamp
    }
}

/// Orchestrator uniting ScreenCaptureKit screen capture, Interactive Cropper, and Neural Engine OCR.
public actor ScreenVisionCoordinator {
    private let captureService: ScreenCaptureService
    private let ocrService: VisionOCRService
    
    // In-memory OCR cache keyed by image SHA-256 to prevent duplicate OCR computation
    private var ocrCache: [String: OCRResult] = [:]
    private let maxCacheEntries = 20
    
    public init(
        captureService: ScreenCaptureService = ScreenCaptureService(),
        ocrService: VisionOCRService = VisionOCRService()
    ) {
        self.captureService = captureService
        self.ocrService = ocrService
    }
    
    /// Converts a Cocoa screen rect (origin bottom-left) to a CoreGraphics screen rect (origin top-left).
    public static func cocoaRectToCoreGraphicsRect(_ cocoaRect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let cgY = primaryHeight - cocoaRect.maxY
        return CGRect(
            x: cocoaRect.origin.x,
            y: cgY,
            width: cocoaRect.width,
            height: cocoaRect.height
        )
    }
    
    /// Converts a CoreGraphics screen rect (origin top-left) to a Cocoa screen rect (origin bottom-left).
    public static func coreGraphicsRectToCocoaRect(_ cgRect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let cocoaY = primaryHeight - (cgRect.origin.y + cgRect.height)
        return CGRect(
            x: cgRect.origin.x,
            y: cocoaY,
            width: cgRect.width,
            height: cgRect.height
        )
    }
    
    /// Captures the specified region, runs OCR, and packages the complete ScreenContext.
    public func captureAndAnalyze(
        region: ScreenRegion,
        ocrMode: VisionOCRService.RecognitionMode = .accurate
    ) async throws -> ScreenContext? {
        let (cgImage, targetBounds): (CGImage, CGRect)
        
        switch region {
        case .mainDisplay:
            let image = try await captureService.captureMainDisplay()
            let bounds = CGDisplayBounds(CGMainDisplayID())
            (cgImage, targetBounds) = (image, bounds)
            
        case .display(let displayID):
            let image = try await captureService.captureDisplay(displayID: displayID)
            let bounds = CGDisplayBounds(displayID)
            (cgImage, targetBounds) = (image, bounds)
            
        case .customRect(let rect):
            let image = try await captureService.captureRect(rect)
            (cgImage, targetBounds) = (image, rect)
            
        case .interactiveCropper:
            guard let selectedCocoaRect = await InteractiveCropper().promptForCropSelection() else {
                return nil // User cancelled selection
            }
            let cgRect = Self.cocoaRectToCoreGraphicsRect(selectedCocoaRect)
            let image = try await captureService.captureRect(cgRect)
            (cgImage, targetBounds) = (image, cgRect)
        }
        
        // Compute SHA-256 fingerprint for cache deduplication
        let hash = ImageProcessor.computeHash(cgImage: cgImage)
        
        // Check OCR cache
        let ocrResult: OCRResult
        if let cached = ocrCache[hash] {
            ocrResult = cached
        } else {
            let freshOCR = try await ocrService.recognizeText(in: cgImage, mode: ocrMode)
            ocrCache[hash] = freshOCR
            pruneCacheIfNeeded()
            ocrResult = freshOCR
        }
        
        // Encode PNG and Base64 Data URL
        let pngData = try ImageProcessor.encode(cgImage: cgImage, format: .png)
        let base64Url = "data:image/png;base64,\(pngData.base64EncodedString())"
        
        return ScreenContext(
            cgImage: cgImage,
            pngData: pngData,
            base64DataUrl: base64Url,
            ocrResult: ocrResult,
            bounds: targetBounds,
            imageHash: hash,
            timestamp: Date()
        )
    }
    
    /// Clears the OCR result cache.
    public func clearCache() {
        ocrCache.removeAll()
    }
    
    private func pruneCacheIfNeeded() {
        if ocrCache.count > maxCacheEntries {
            ocrCache.removeAll()
        }
    }
}
