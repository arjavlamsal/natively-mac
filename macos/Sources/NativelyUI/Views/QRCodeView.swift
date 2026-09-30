import SwiftUI
import CoreImage.CIFilterBuiltins
import AppKit

/// Renders a sharp, high-DPI QR code from text or URL using Apple CoreImage.
public struct QRCodeView: View {
    public let content: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    public init(content: String) {
        self.content = content
    }
    
    public var body: some View {
        if let image = generateQRCode(from: content) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
        }
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
