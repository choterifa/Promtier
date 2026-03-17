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
                        }
                        
                        let newWidth = max(500, initialSize.width + value.translation.width)
                        let newHeight = max(450, initialSize.height + value.translation.height)
                        
                        preferences.windowWidth = newWidth
                        preferences.windowHeight = newHeight
                    }
                    .onEnded { _ in
                        initialSize = .zero
                        preferences.saveWindowDimensions()
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
