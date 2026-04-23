import SwiftUI

public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        ScaleButtonLabel(configuration: configuration)
    }
    
    struct ScaleButtonLabel: View {
        let configuration: Configuration
        @State private var isHovering = false
        
        var body: some View {
            configuration.label
                .brightness(isHovering ? 0.05 : 0)
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
}
