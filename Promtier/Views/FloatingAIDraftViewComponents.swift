//
//  FloatingAIDraftViewComponents.swift
//  Promtier
//
//  VISTAS: Componentes internos para la vista de borrador rápido.
//

import SwiftUI

/// Renderiza un diff visual entre dos textos usando tokens de DiffEngine
struct DiffTextView: View {
    let oldText: String
    let newText: String
    
    @State private var tokens: [DiffToken] = []
    
    var body: some View {
        AIDraftFlowLayout(spacing: 4, alignment: .leading) {
            ForEach(tokens) { token in
                Text(token.text)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 2)
                    .background(backgroundColor(for: token.type))
                    .foregroundColor(foregroundColor(for: token.type))
                    .strikethrough(token.type == .removed)
                    .cornerRadius(4)
            }
        }
        .onAppear { compute() }
        .onChange(of: oldText) { _, _ in compute() }
        .onChange(of: newText) { _, _ in compute() }
    }
    
    private func compute() {
        tokens = DiffEngine.computeDiff(oldText: oldText, newText: newText)
    }
    
    private func backgroundColor(for type: DiffType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        case .unchanged: return Color.clear
        }
    }
    
    private func foregroundColor(for type: DiffType) -> Color {
        switch type {
        case .added: return Color.green
        case .removed: return Color.red.opacity(0.8)
        case .unchanged: return Color.primary.opacity(0.8)
        }
    }
}

/// Layout flexible para palabras en un diff (Flow layout)
struct AIDraftFlowLayout: Layout {
    var spacing: CGFloat = 4
    var alignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.width ?? 0)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for i in subviews.indices {
            subviews[i].place(at: CGPoint(x: bounds.minX + result.points[i].x, y: bounds.minY + result.points[i].y), proposal: ProposedViewSize(subviews[i].sizeThatFits(.unspecified)))
        }
    }
    
    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX)
        }
        
        return (CGSize(width: totalWidth, height: currentY + lineHeight), points)
    }
}

/// Botón pequeño circular para acciones secundarias
struct CircularActionButton: View {
    let icon: String
    let tooltip: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isHovered ? .white : color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isHovered ? color : color.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
    }
}

/// Estilo de botón con hover suave SIN escala (color y opacidad)
struct PlainHoverButtonStyle: ButtonStyle {
    var color: Color = .primary
    var active: Bool = false
    var padding: (h: CGFloat, v: CGFloat) = (8, 4)
    
    func makeBody(configuration: Configuration) -> some View {
        _PlainHoverButtonBody(configuration: configuration, color: color, active: active, padding: padding)
    }
}

private struct _PlainHoverButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let color: Color
    let active: Bool
    let padding: (h: CGFloat, v: CGFloat)
    
    @State private var isHovered = false
    
    var body: some View {
        configuration.label
            .foregroundColor(active || isHovered ? color : .secondary)
            .padding(.horizontal, padding.h)
            .padding(.vertical, padding.v)
            .background(
                Capsule()
                    .fill(active || isHovered ? color.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .onHover { isHovered = $0 }
    }
}
