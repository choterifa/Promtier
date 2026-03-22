import SwiftUI

struct ResizeHandle: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var initialSize: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Grabber visual (tres líneas diagonales)
            Canvas { context, size in
                for i in 0..<3 {
                    let offset = CGFloat(i) * 4
                    var path = Path()
                    path.move(to: CGPoint(x: size.width - 2 - offset, y: size.height - 2))
                    path.addLine(to: CGPoint(x: size.width - 2, y: size.height - 2 - offset))
                    context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: 1.5)
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if initialSize == .zero {
                            initialSize = CGSize(width: preferences.windowWidth, height: preferences.windowHeight)
                            HapticService.shared.playLight()
                        }
                        
                        let newWidth = min(900, max(500, initialSize.width + value.translation.width))
                        let newHeight = min(750, max(450, initialSize.height + value.translation.height))
                        
                        // Retroalimentación táctica cada 20px
                        let oldW = Int(preferences.windowWidth / 20)
                        let newW = Int(newWidth / 20)
                        let oldH = Int(preferences.windowHeight / 20)
                        let newH = Int(newHeight / 20)
                        
                        if oldW != newW || oldH != newH {
                            HapticService.shared.playImpact()
                        }
                        
                        preferences.windowWidth = newWidth
                        preferences.windowHeight = newHeight
                        
                        // Mostrar HUD de redimensionado
                        preferences.isResizingVisible = true
                        
                        // Sincronizar previsualización para el HUD y Sliders
                        preferences.previewWidth = newWidth
                        preferences.previewHeight = newHeight
                    }
                    .onEnded { _ in
                        initialSize = .zero
                        preferences.isResizingVisible = false
                        preferences.saveWindowDimensions()
                        HapticService.shared.playAlignment()
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
