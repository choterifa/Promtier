import SwiftUI
import UniformTypeIdentifiers

public struct MagicGlobalDropOverlay: ViewModifier {
    @State private var isDragging: Bool = false
    @State private var droppedImage: NSImage? = nil
    @State private var isPulsing: Bool = false
    
    let isProcessing: Bool
    let onImageDropped: (Data) -> Void
    
    public func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if isDragging || isProcessing {
                        // Blurred background
                        Rectangle()
                            .fill(.regularMaterial)
                            .opacity(isDragging ? 0.8 : (isProcessing ? 0.95 : 0))
                            .edgesIgnoringSafeArea(.all)
                        
                        // Dashed Border
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.blue.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [10]))
                            .padding(12)
                        
                        VStack(spacing: 20) {
                            if isProcessing, let img = droppedImage {
                                // Processing Preview
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .cornerRadius(12)
                                    .shadow(radius: 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                    .overlay(
                                        // Magical scanner line
                                        Rectangle()
                                            .fill(
                                                LinearGradient(gradient: Gradient(colors: [.clear, .blue.opacity(0.6), .clear]), startPoint: .top, endPoint: .bottom)
                                            )
                                            .frame(height: 20)
                                            .offset(y: isPulsing ? 90 : -90)
                                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                                    )
                                
                                Text("Analizando imagen con IA...")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            } else {
                                // Dragging Message
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
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .animation(.easeInOut(duration: 0.3), value: isProcessing)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
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
}

public extension View {
    func magicGlobalDropOverlay(isProcessing: Bool, onImageDropped: @escaping (Data) -> Void) -> some View {
        self.modifier(MagicGlobalDropOverlay(isProcessing: isProcessing, onImageDropped: onImageDropped))
    }
}
