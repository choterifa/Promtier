import SwiftUI
import UniformTypeIdentifiers

public struct MagicGlobalDropOverlay: ViewModifier {
    @State private var isDragging: Bool = false
    @State private var droppedImage: NSImage? = nil
    @State private var isPulsing: Bool = false
    
    let isProcessing: Bool
    let onImageDropped: (Data) -> Void
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            // Capa de Intercepción de Drag & Drop (Nivel Senior)
            // Usamos un color con opacidad mínima para que SwiftUI lo considere una superficie válida de drop
            // pero que no bloquee la interacción normal del usuario con el editor inferior.
            Color.white.opacity(0.00001)
                .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
                    handleDropProviders(providers)
                }
                // El truco maestro: solo permitimos que esta capa reciba eventos de 'hit testing' 
                // cuando ya hay un drag activo o estamos procesando. 
                // Esto permite que el cursor y los clics sigan funcionando en el editor de abajo.
                .allowsHitTesting(isDragging || isProcessing)
                .edgesIgnoringSafeArea(.all)

            // UI Visual del Overlay
            if isDragging || isProcessing {
                visualOverlayContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .onChange(of: isProcessing) { _, processing in
            if processing {
                isPulsing = true
            } else {
                isPulsing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.droppedImage = nil
                }
            }
        }
    }

    @ViewBuilder
    private var visualOverlayContent: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(isDragging ? 0.8 : (isProcessing ? 0.95 : 0))
                .edgesIgnoringSafeArea(.all)
            
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [10]))
                .padding(12)
            
            VStack(spacing: 20) {
                if isProcessing, let img = droppedImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.6), radius: 20, x: 0, y: 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Analizando imagen con IA...")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true), value: isDragging)
                    
                    VStack(spacing: 4) {
                        Text("Suelta para extraer Prompt")
                            .font(.system(size: 22, weight: .heavy))
                        Text("Magia visual con IA")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) || 
               provider.hasItemConformingToTypeIdentifier(UTType.zip.identifier) {
                return false
            }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data = data, let img = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        self.droppedImage = img
                        self.isPulsing = true
                        onImageDropped(data)
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) else { return }
                    let ext = url.pathExtension.lowercased()
                    if ext == "json" || ext == "zip" { return }
                    guard let imgData = try? Data(contentsOf: url), let img = NSImage(data: imgData) else { return }
                    DispatchQueue.main.async {
                        self.droppedImage = img
                        self.isPulsing = true
                        onImageDropped(imgData)
                    }
                }
                return true
            }
        }
        return false
    }
}

public extension View {
    func magicGlobalDropOverlay(isProcessing: Bool, onImageDropped: @escaping (Data) -> Void) -> some View {
        self.modifier(MagicGlobalDropOverlay(isProcessing: isProcessing, onImageDropped: onImageDropped))
    }
}
