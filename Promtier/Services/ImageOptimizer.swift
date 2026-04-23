import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageOptimizer: @unchecked Sendable {
    nonisolated static let shared = ImageOptimizer()
    
    private init() {}
    
    /// Optimiza una imagen: Redimensiona a max 720px y comprime a JPEG con calidad 0.8
    nonisolated func optimize(imageData: Data) -> Data? {
        optimize(imageData: imageData, maxPixelSize: 720, compressionQuality: 0.8)
    }

    /// Optimiza para guardado en disco, devolviendo también la extensión sugerida.
    nonisolated func optimizeForDisk(imageData: Data, maxPixelSize: Int, compressionQuality: Double) -> (data: Data, fileExtension: String)? {
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

        let destUTType = hasAlpha ? UTType.png : UTType.jpeg
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, destUTType.identifier as CFString, 1, nil) else { return nil }

        var properties: [CFString: Any] = [:]
        if destUTType == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = compressionQuality
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        let ext = (destUTType == .png) ? "png" : "jpg"
        return (mutableData as Data, ext)
    }

    /// Optimiza una imagen de forma eficiente (sin decodificar a tamaño completo en memoria).
    nonisolated func optimize(imageData: Data, maxPixelSize: Int, compressionQuality: Double) -> Data? {
        optimizeForDisk(imageData: imageData, maxPixelSize: maxPixelSize, compressionQuality: compressionQuality)?.data
    }
}
