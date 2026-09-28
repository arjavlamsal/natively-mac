import Testing
import Foundation
import CoreGraphics
import CoreText
import AppKit
@testable import NativelyVision

@Suite("NativelyVision Pipeline Tests")
struct VisionPipelineTests {
    
    // Helper to generate a synthetic bitmap CGImage with rendered text
    private func createTestImageWithText(_ text: String, width: Int = 600, height: Int = 200) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!
        
        // Fill white background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw crisp black text using CoreText
        let font = CTFontCreateWithName("Helvetica" as CFString, 36.0, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black.cgColor
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        
        context.textPosition = CGPoint(x: 30, y: 80)
        CTLineDraw(line, context)
        
        return context.makeImage()!
    }
    
    @Test("CaptureGeometry pixel size calculations")
    func testCaptureGeometry() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)
        let geom1x = CaptureGeometry(bounds: rect, scaleFactor: 1.0)
        #expect(geom1x.pixelSize == CGSize(width: 400, height: 300))
        
        let geom2x = CaptureGeometry(bounds: rect, scaleFactor: 2.0)
        #expect(geom2x.pixelSize == CGSize(width: 800, height: 600))
    }
    
    @Test("ImageProcessor cropping and dimension clamping")
    func testImageProcessorCropping() throws {
        let sourceImage = createTestImageWithText("Sample Crop Text", width: 800, height: 400)
        let displayBounds = CGRect(x: 0, y: 0, width: 400, height: 200) // 2x display
        let cropSelection = CGRect(x: 50, y: 25, width: 100, height: 50)
        
        let cropped = try ImageProcessor.crop(
            cgImage: sourceImage,
            displayLogicalBounds: displayBounds,
            selectionLogicalRect: cropSelection
        )
        
        // At 2x scale, 100x50 selection should produce a 200x100 pixel cropped image
        #expect(cropped.width == 200)
        #expect(cropped.height == 100)
    }
    
    @Test("ImageProcessor encoding to PNG, JPEG and Base64 Data URL")
    func testImageProcessorEncoding() throws {
        let testImage = createTestImageWithText("Encode Test", width: 200, height: 100)
        
        // PNG encoding
        let pngData = try ImageProcessor.encode(cgImage: testImage, format: .png)
        #expect(!pngData.isEmpty)
        #expect(pngData.count > 100)
        
        // JPEG encoding
        let jpegData = try ImageProcessor.encode(cgImage: testImage, format: .jpeg(quality: 0.8))
        #expect(!jpegData.isEmpty)
        
        // Base64 Data URL
        let base64Url = try ImageProcessor.encodeBase64DataUrl(cgImage: testImage, format: .png)
        #expect(base64Url.hasPrefix("data:image/png;base64,"))
    }
    
    @Test("ImageProcessor SHA-256 fingerprinting and deduplication")
    func testImageProcessorHashing() {
        let image1 = createTestImageWithText("Identical Text", width: 300, height: 100)
        let image2 = createTestImageWithText("Identical Text", width: 300, height: 100)
        let differentImage = createTestImageWithText("Completely Different Content", width: 300, height: 100)
        
        let hash1 = ImageProcessor.computeHash(cgImage: image1)
        let hash2 = ImageProcessor.computeHash(cgImage: image2)
        let hashDifferent = ImageProcessor.computeHash(cgImage: differentImage)
        
        #expect(hash1 == hash2)
        #expect(hash1 != hashDifferent)
        #expect(hash1.count == 64) // 64 hex characters for SHA-256
    }
    
    @Test("VisionOCRService accurately recognizes rendered text on Neural Engine")
    func testVisionOCRTextRecognition() async throws {
        let testString = "Natively Native Transformation 2026"
        let testImage = createTestImageWithText(testString, width: 800, height: 200)
        
        let ocrService = VisionOCRService()
        let result = try await ocrService.recognizeText(in: testImage, mode: .accurate)
        
        #expect(!result.isEmpty)
        #expect(result.fullText.contains("Natively"))
        #expect(result.fullText.contains("Transformation"))
        #expect(result.lines.count > 0)
        #expect(result.averageConfidence > 0.7)
        #expect(result.executionDurationMs > 0)
    }
    
    @Test("ScreenVisionCoordinator coordinate conversions between Cocoa and CoreGraphics")
    func testCoordinateConversions() {
        let cocoaRect = CGRect(x: 100, y: 200, width: 300, height: 150)
        let cgRect = ScreenVisionCoordinator.cocoaRectToCoreGraphicsRect(cocoaRect)
        let roundTrip = ScreenVisionCoordinator.coreGraphicsRectToCocoaRect(cgRect)
        
        #expect(roundTrip.origin.x == cocoaRect.origin.x)
        #expect(roundTrip.origin.y == cocoaRect.origin.y)
        #expect(roundTrip.width == cocoaRect.width)
        #expect(roundTrip.height == cocoaRect.height)
    }
}
