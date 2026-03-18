import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageOptimizer: @unchecked Sendable {
    nonisolated static let shared = ImageOptimizer()
    
    private init() {}
    
    /// Optimiza una imagen: Redimensiona a max 1200px y comprime a JPEG con calidad 0.8
    nonisolated func optimize(imageData: Data) -> Data? {
        optimize(imageData: imageData, maxPixelSize: 1200, compressionQuality: 0.8)
    }

    /// Optimiza una imagen de forma eficiente (sin decodificar a tamaño completo en memoria).
    nonisolated func optimize(imageData: Data, maxPixelSize: Int, compressionQuality: Double) -> Data? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(imageData as CFData, sourceOptions as CFDictionary) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }

        let alpha = cgImage.alphaInfo
        let hasAlpha = alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast

        let destType: CFString = (hasAlpha ? UTType.png.identifier : UTType.jpeg.identifier) as CFString
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, destType, 1, nil) else { return nil }

        var properties: [CFString: Any] = [:]
        if !hasAlpha {
            properties[kCGImageDestinationLossyCompressionQuality] = compressionQuality
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
