import SwiftUI
import Combine

struct MarchingAntsBorderModifier: ViewModifier {
    let isActive: Bool
    let tintColor: Color
    let cornerRadius: CGFloat
    let baseLineWidth: CGFloat
    let baseDash: [CGFloat]
    let baseColor: Color
    
    @State private var dashPhase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: baseLineWidth,
                            dash: baseDash,
                            dashPhase: dashPhase
                        )
                    )
                    .foregroundColor(baseColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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
                        lineWidth: baseLineWidth + 1.0
                    )
                    .opacity(isActive ? 1.0 : 0)
                    .blendMode(.plusLighter)
                    .animation(.easeInOut(duration: 0.3), value: isActive)
            )
            .onReceive(Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()) { _ in
                if isActive {
                    dashPhase -= 0.1
                }
            }
    }
}

extension View {
    func marchingAntsBorder(
        isActive: Bool,
        tintColor: Color,
        cornerRadius: CGFloat = 12,
        baseLineWidth: CGFloat = 1.5,
        baseDash: [CGFloat] = [6, 4],
        baseColor: Color = .secondary.opacity(0.8)
    ) -> some View {
        self.modifier(
            MarchingAntsBorderModifier(
                isActive: isActive,
                tintColor: tintColor,
                cornerRadius: cornerRadius,
                baseLineWidth: baseLineWidth,
                baseDash: baseDash,
                baseColor: baseColor
            )
        )
    }
}
