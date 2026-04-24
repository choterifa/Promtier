import SwiftUI
import UniformTypeIdentifiers

public struct MagicImageDropZone: View {
    @Binding var isDraggingImage: Bool
    @State private var showUnsupportedAlert: Bool = false
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
        .help("Arrastra y suelta una imagen o PDF aquí adentro para analizarlo mágicamente")
        .alert("Formato no soportado", isPresented: $showUnsupportedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Solo se admiten imágenes y archivos PDF para extraer el prompt. Por favor, intenta con un formato válido (JPG, PNG, PDF, etc).")
        }
        .onDrop(of: [.image, .pdf, .fileURL], isTargeted: $isDraggingImage) { providers in
            var handled = false
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ? UTType.pdf.identifier : UTType.image.identifier
                    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                        guard let data = data, (NSImage(data: data) != nil || typeIdentifier == UTType.pdf.identifier) else {
                            DispatchQueue.main.async { self.showUnsupportedAlert = true }
                            return
                        }
                        DispatchQueue.main.async { onImageDropped(data) }
                    }
                    handled = true
                    break
                } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        guard let data = data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) else {
                            DispatchQueue.main.async { self.showUnsupportedAlert = true }
                            return
                        }
                        let ext = url.pathExtension.lowercased()
                        guard let fileData = try? Data(contentsOf: url), (NSImage(data: fileData) != nil || ext == "pdf") else {
                            DispatchQueue.main.async { self.showUnsupportedAlert = true }
                            return
                        }
                        DispatchQueue.main.async { onImageDropped(fileData) }
                    }
                    handled = true
                    break
                }
            }
            if !handled {
                DispatchQueue.main.async { self.showUnsupportedAlert = true }
            }
            return handled
        }
    }
}
