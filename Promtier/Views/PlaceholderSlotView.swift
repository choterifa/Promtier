import SwiftUI
import UniformTypeIdentifiers
import Combine


struct PlaceholderSlotView: View {
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
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

            Text("add_prompt_results".localized(for: preferences.language))
                .font(.system(size: 11, weight: .medium))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            AngularGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: tintColor.opacity(0.1), location: 0.3),
                                    .init(color: tintColor.opacity(0.4), location: 0.6),
                                    .init(color: tintColor.opacity(0.7), location: 0.8),
                                    .init(color: tintColor.opacity(0.9), location: 0.95),
                                    .init(color: .clear, location: 1.0)
                                ],
                                center: .center,
                                angle: .degrees(Double(-dashPhase * 24))
                            ),
                            lineWidth: 2.5
                        )
                        .opacity((isHovering || isTargeted) ? 1.0 : 0)
                        .blendMode(.plusLighter)
                        .animation(.easeInOut(duration: 0.3), value: isHovering || isTargeted)
                )
        )
        .scaleEffect(isTargeted ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onHover { hovering in
            // Cambio de estado sin withAnimation global para evitar saltos
            isHovering = hovering
        }
        .onChange(of: isHovering || isTargeted) { _, isActive in
            if isActive {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    dashPhase -= 15
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    dashPhase = 0
                }
            }
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
