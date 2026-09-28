import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO
import CryptoKit

public enum ImageProcessorError: Error, LocalizedError {
    case croppingFailed(String)
    case encodingFailed(String)
    case invalidDimensions(String)
    
    public var errorDescription: String? {
        switch self {
        case .croppingFailed(let msg): return "Image cropping failed: \(msg)"
        case .encodingFailed(let msg): return "Image encoding failed: \(msg)"
        case .invalidDimensions(let msg): return "Invalid image dimensions: \(msg)"
        }
    }
}

public enum ImageFormat: Sendable {
    case png
    case jpeg(quality: CGFloat)
    
    public var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        }
    }
}

/// Hardware-accelerated CoreGraphics image operations and encodings.
public final class ImageProcessor: Sendable {
    public init() {}
    
    /// Crops a `CGImage` according to a logical selection relative to the display's logical bounds.
    /// Accurately scales points to physical backing pixels.
    public static func crop(
        cgImage: CGImage,
        displayLogicalBounds: CGRect,
        selectionLogicalRect: CGRect
    ) throws -> CGImage {
        guard displayLogicalBounds.width > 0 && displayLogicalBounds.height > 0 else {
            throw ImageProcessorError.invalidDimensions("Display bounds cannot have zero dimensions.")
        }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        let ratioX = imageWidth / displayLogicalBounds.width
        let ratioY = imageHeight / displayLogicalBounds.height
        
        // Compute selection relative to display origin
        let relX = (selectionLogicalRect.origin.x - displayLogicalBounds.origin.x) * ratioX
        let relY = (selectionLogicalRect.origin.y - displayLogicalBounds.origin.y) * ratioY
        let relWidth = selectionLogicalRect.width * ratioX
        let relHeight = selectionLogicalRect.height * ratioY
        
        // Clamp inside image bounds
        let cropX = max(0, min(relX, imageWidth))
        let cropY = max(0, min(relY, imageHeight))
        let cropWidth = max(1, min(relWidth, imageWidth - cropX))
        let cropHeight = max(1, min(relHeight, imageHeight - cropY))
        
        let pixelRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        guard let cropped = cgImage.cropping(to: pixelRect) else {
            throw ImageProcessorError.croppingFailed("CoreGraphics failed to crop rect: \(pixelRect)")
        }
        
        return cropped
    }
    
    /// Encodes a `CGImage` into compressed `Data` (`.png` or `.jpeg`).
    public static func encode(
        cgImage: CGImage,
        format: ImageFormat = .png
    ) throws -> Data {
        let outputData = NSMutableData()
        let uti: CFString
        let properties: CFDictionary?
        
        switch format {
        case .png:
            uti = UTType.png.identifier as CFString
            properties = nil
        case .jpeg(let quality):
            uti = UTType.jpeg.identifier as CFString
            let q = min(1.0, max(0.0, quality))
            properties = [kCGImageDestinationLossyCompressionQuality as String: q] as CFDictionary
        }
        
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData,
            uti,
            1,
            nil
        ) else {
            throw ImageProcessorError.encodingFailed("Failed to create image destination for \(format.mimeType)")
        }
        
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageProcessorError.encodingFailed("Failed to finalize image destination")
        }
        
        return outputData as Data
    }
    
    /// Encodes a `CGImage` into a base64 Data URL (e.g. `data:image/png;base64,...`) for AI vision APIs.
    public static func encodeBase64DataUrl(
        cgImage: CGImage,
        format: ImageFormat = .png
    ) throws -> String {
        let data = try encode(cgImage: cgImage, format: format)
        let base64 = data.base64EncodedString()
        return "data:\(format.mimeType);base64,\(base64)"
    }
    
    /// Calculates a fast SHA-256 hash of the image data for caching and deduplication.
    public static func computeHash(cgImage: CGImage) -> String {
        if let data = try? encode(cgImage: cgImage, format: .jpeg(quality: 0.7)) {
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString
    }
}
