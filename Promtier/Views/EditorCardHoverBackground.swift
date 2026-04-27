import SwiftUI

struct EditorCardHoverBackground: View {
    let isTyping: Bool
    let themeColor: Color
    let currentCategoryColor: Color
    let isHaloEffectEnabled: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
            .fill(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                    .stroke(
                        themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)),
                        lineWidth: isTyping ? Theme.Layout.EditorCard.activeBorderWidth : Theme.Layout.EditorCard.idleBorderWidth
                    )
                    .shadow(
                        color: isHaloEffectEnabled ? currentCategoryColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear,
                        radius: isTyping ? 10 : (isHovering ? 6 : 4)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTyping)
            .onHover { hovering in
                guard isHovering != hovering else { return }
                isHovering = hovering
            }
    }
}
