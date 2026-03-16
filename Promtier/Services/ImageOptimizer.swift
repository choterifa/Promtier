import Foundation
import AppKit

class ImageOptimizer {
    static let shared = ImageOptimizer()
    
    private init() {}
    
    /// Optimiza una imagen: Redimensiona a max 1200px y comprime a JPEG con calidad 0.8
    func optimize(imageData: Data) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        
        let maxWidth: CGFloat = 1200
        let maxHeight: CGFloat = 1200
        
        var newSize = image.size
        
        // Calcular nuevo tamaño manteniendo ratio
        if newSize.width > maxWidth || newSize.height > maxHeight {
            let widthRatio = maxWidth / newSize.width
            let heightRatio = maxHeight / newSize.height
            let ratio = min(widthRatio, heightRatio)
            
            newSize = CGSize(width: newSize.width * ratio, height: newSize.height * ratio)
        }
        
        // Redimensionar
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), 
                   from: NSRect(origin: .zero, size: image.size), 
                   operation: .sourceOver, 
                   fraction: 1.0)
        newImage.unlockFocus()
        
        // Comprimir a JPEG 0.8
        guard let tiffRepresentation = newImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
