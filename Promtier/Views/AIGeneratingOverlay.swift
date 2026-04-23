import SwiftUI

struct AIGeneratingOverlay: View {
    let accentColor: Color
    var compact: Bool = false

    @State private var pulse = false
    @State private var shimmer = false
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        ZStack {
            // Capa de vidrio esmerilado
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    accentColor.opacity(0.03)
                )

            // Efectos de luz ambiente
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(pulse ? 0.3 : 0.1))
                    .frame(width: compact ? 100 : 200, height: compact ? 100 : 200)
                    .blur(radius: compact ? 30 : 60)
                    .scaleEffect(pulse ? 1.2 : 0.8)

                Circle()
                    .fill(accentColor.opacity(pulse ? 0.1 : 0.2))
                    .frame(width: compact ? 80 : 150, height: compact ? 80 : 150)
                    .blur(radius: compact ? 25 : 50)
                    .offset(x: pulse ? 20 : -20, y: pulse ? -10 : 10)
            }
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: compact ? 12 : 16) {
                // Icono animado
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 24 : 32, weight: .bold))
                        .foregroundColor(.purple)
                        .symbolEffect(.variableColor.reversing.iterative)

                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 24 : 32, weight: .bold))
                        .foregroundColor(.purple)
                        .blur(radius: 8)
                        .opacity(pulse ? 0.8 : 0.3)
                }

                VStack(spacing: 4) {
                    Text("ai_thinking".localized(for: preferences.language))
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))

                    if !compact {
                        Text("ai_crafting_message".localized(for: preferences.language))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Barra de progreso elegante
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: compact ? 100 : 160, height: 4)

                    Capsule()
                        .fill(preferences.isHaloEffectEnabled ?
                            AnyShapeStyle(LinearGradient(colors: [.purple, accentColor], startPoint: .leading, endPoint: .trailing)) :
                            AnyShapeStyle(accentColor))
                        .frame(width: shimmer ? (compact ? 100 : 160) : 0, height: 4)
                }
                .mask(
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing))
                        .offset(x: shimmer ? (compact ? 150 : 250) : (compact ? -150 : -250))
                )
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}
