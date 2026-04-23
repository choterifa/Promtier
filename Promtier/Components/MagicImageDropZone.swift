import SwiftUI
import UniformTypeIdentifiers

public struct MagicImageDropZone: View {
    @Binding var isDraggingImage: Bool
    var onImageDropped: (Data) -> Void
    
    public init(isDraggingImage: Binding<Bool>, onImageDropped: @escaping (Data) -> Void) {
        self._isDraggingImage = isDraggingImage
        self.onImageDropped = onImageDropped
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isDraggingImage ? Color.blue.opacity(0.15) : Color.primary.opacity(0.04))
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDraggingImage ? Color.blue.opacity(0.8) : Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: isDraggingImage ? 1.5 : 1, dash: isDraggingImage ? [4] : []))
            
            Image(systemName: isDraggingImage ? "sparkles.tv" : "photo.on.rectangle.angled")
                .font(.system(size: 14))
                .foregroundColor(isDraggingImage ? .blue : .secondary)
        }
        .frame(width: 38, height: 38)
        .help("Arrastra y suelta una imagen aquí adentro para analizarla mágicamente")
        .onDrop(of: [.image, .fileURL], isTargeted: $isDraggingImage) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        guard let data = data else { return }
                        DispatchQueue.main.async { onImageDropped(data) }
                    }
                    return true
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        guard let data = data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) else { return }
                        guard let imgData = try? Data(contentsOf: url) else { return }
                        if NSImage(data: imgData) != nil {
                            DispatchQueue.main.async { onImageDropped(imgData) }
                        }
                    }
                    return true
                }
            }
            return false
        }
    }
}
