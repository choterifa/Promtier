import SwiftUI
import AppKit

struct ResizeHandle: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var isDragging: Bool = false
    @State private var dragStartSize: CGSize = .zero
    @State private var isHovered: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Área de hit invisible, cubre toda la esquina inferior-derecha
            Rectangle()
                .fill(Color.clear)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                // Ícono visual: solo 3 líneas diagonales sutiles
                .overlay(
                    Canvas { context, size in
                        for i in 0..<3 {
                            let offset = CGFloat(i) * 4
                            var path = Path()
                            path.move(to: CGPoint(x: size.width - 2 - offset, y: size.height - 2))
                            path.addLine(to: CGPoint(x: size.width - 2, y: size.height - 2 - offset))
                            context.stroke(
                                path,
                                with: .color(.secondary.opacity(isDragging ? 0.7 : (isHovered ? 0.5 : 0.25))),
                                lineWidth: 1.5
                            )
                        }
                    }
                )
                .onHover { inside in
                    isHovered = inside
                    if inside {
                        NSCursor.crosshair.push()
                    } else if !isDragging {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            if !isDragging {
                                // Capturamos el tamaño INICIAL solo una vez
                                isDragging = true
                                dragStartSize = CGSize(
                                    width: preferences.windowWidth,
                                    height: preferences.windowHeight
                                )
                                HapticService.shared.playLight()
                            }

                            // Delta puro: rastreo perfecto sin importar velocidad del mouse
                            let newWidth  = min(900, max(500, dragStartSize.width  + value.translation.width))
                            let newHeight = min(750, max(450, dragStartSize.height + value.translation.height))

                            // Feedback táctil cada 20px
                            let oldW = Int(preferences.windowWidth  / 20)
                            let newW = Int(newWidth  / 20)
                            let oldH = Int(preferences.windowHeight / 20)
                            let newH = Int(newHeight / 20)
                            if oldW != newW || oldH != newH {
                                HapticService.shared.playImpact()
                            }

                            preferences.windowWidth  = newWidth
                            preferences.windowHeight = newHeight
                            preferences.previewWidth  = newWidth
                            preferences.previewHeight = newHeight
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragStartSize = .zero
                            if !isHovered {
                                NSCursor.pop()
                            }
                            HapticService.shared.playAlignment()
                        }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
