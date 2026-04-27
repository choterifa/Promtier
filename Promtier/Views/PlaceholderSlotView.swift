import SwiftUI
import UniformTypeIdentifiers
import Combine


struct PlaceholderSlotView: View {
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    var displayTextKey: String = "add_prompt_results"
    var tintColor: Color = .blue
    
    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var dashPhase: CGFloat = 0
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 0.8 : 0.4))

            Text(displayTextKey.localized(for: preferences.language))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 0.8 : 0.4))
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .frame(width: slotWidth, height: slotHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? tintColor.opacity(0.1) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        // El lineWidth fijo para hover evita que StrokeStyle anime incorrectamente el dashPhase
                        .stroke(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: isTargeted ? [] : [6, 4], dashPhase: dashPhase))
                        .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 1.0 : 0.8))
                        .animation(.easeInOut(duration: 0.15), value: isHovering)
                )
        )
        .scaleEffect(isTargeted ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .contentShape(Rectangle())
        .onHover { hovering in
            // Cambio de estado sin withAnimation global para evitar saltos
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onDrop(of: [.image, .fileURL, .url], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}
