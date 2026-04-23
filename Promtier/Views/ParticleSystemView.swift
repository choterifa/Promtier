//
//  ParticleSystemView.swift
//  Promtier
//
//  COMPONENTE: Confeti Premium — formas mixtas, colores equilibrados
//

import SwiftUI

// MARK: - Formas de confeti
private enum ConfettiShape: CaseIterable {
    case circle, square, rectangle, diamond
}

// MARK: - Modelo
private struct Confetto: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat        // px/s
    var vy: CGFloat        // px/s
    var angularV: Double   // grados/s
    var angle: Double      // grados (rotación actual)
    var width: CGFloat
    var height: CGFloat
    var color: Color
    var shape: ConfettiShape
    var age: Double
    let life: Double
    var opacity: Double
}

// MARK: - Vista
struct ParticleSystemView: View {
    let accentColor: Color           // se usa como uno de los colores de la paleta

    @State private var pieces: [Confetto] = []
    @State private var lastTick: Date = .now
    @State private var center: CGPoint = .zero

    private static let count: Int = 45
    private static let gravity: CGFloat = 320   // px/s²
    private static let palette: [Color] = confettiPalette

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                Canvas { drawCtx, size in
                    for p in pieces {
                        guard p.opacity > 0 else { continue }
                        var c = drawCtx
                        c.opacity = max(0, p.opacity)
                        drawConfetto(p, in: &c)
                    }
                }
                .onAppear {
                    center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    lastTick = .now
                    emit(in: geo.size)
                }
                .onChange(of: ctx.date) { _, newDate in
                    let dt = CGFloat(min(newDate.timeIntervalSince(lastTick), 0.05))
                    lastTick = newDate
                    tick(dt: dt)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Dibujo individual

    private func drawConfetto(_ p: Confetto, in ctx: inout GraphicsContext) {
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: .degrees(p.angle))

        let hw = p.width / 2
        let hh = p.height / 2

        switch p.shape {
        case .circle:
            let r = CGRect(x: -hw, y: -hh, width: p.width, height: p.height)
            ctx.fill(Path(ellipseIn: r), with: .color(p.color))

        case .square, .rectangle:
            let r = CGRect(x: -hw, y: -hh, width: p.width, height: p.height)
            var path = Path()
            path.addRoundedRect(in: r, cornerSize: CGSize(width: 2, height: 2))
            ctx.fill(path, with: .color(p.color))

        case .diamond:
            var path = Path()
            path.move(to:    CGPoint(x: 0,   y: -hh))
            path.addLine(to: CGPoint(x: hw,  y: 0))
            path.addLine(to: CGPoint(x: 0,   y: hh))
            path.addLine(to: CGPoint(x: -hw, y: 0))
            path.closeSubpath()
            ctx.fill(path, with: .color(p.color))
        }

        // Reset transform para la siguiente pieza
        ctx.rotate(by: .degrees(-p.angle))
        ctx.translateBy(x: -p.x, y: -p.y)
    }

    // MARK: - Emisión

    private func emit(in size: CGSize) {
        var batch: [Confetto] = []
        
        // Mezclar paleta estándar con el color de acento para personalización
        var colors = Self.palette
        if accentColor != .blue { // si no es el azul por defecto, añadirlo varias veces para que domine
            colors.append(contentsOf: Array(repeating: accentColor, count: 4))
        }

        for _ in 0..<Self.count {
            let shape = ConfettiShape.allCases.randomElement()!
            let isRect = (shape == .rectangle)
            let w: CGFloat = isRect ? CGFloat.random(in: 8...14) : CGFloat.random(in: 7...12)
            let h: CGFloat = isRect ? w * CGFloat.random(in: 1.8...3.0) : w

            // Sale desde arriba del centro (±mitad del ancho)
            let startX = center.x + CGFloat.random(in: -center.x * 0.55...center.x * 0.55)
            let startY = CGFloat.random(in: -30...(-5))  // arriba de la vista

            batch.append(Confetto(
                x:        startX,
                y:        startY,
                vx:       CGFloat.random(in: -85...85),
                vy:       CGFloat.random(in: 110...280),  // hacia abajo
                angularV: Double.random(in: -300...300),
                angle:    Double.random(in: 0...360),
                width:    w,
                height:   h,
                color:    colors.randomElement()!,
                shape:    shape,
                age:      0,
                life:     Double.random(in: 1.5...2.8),
                opacity:  1.0
            ))
        }
        pieces = batch
    }

    // MARK: - Tick

    private func tick(dt: CGFloat) {
        guard !pieces.isEmpty else { return }
        pieces = pieces.compactMap { var p = $0
            p.age     += Double(dt)
            p.vy      += Self.gravity * dt
            // ligero wobble horizontal
            p.vx      += CGFloat.random(in: -18...18) * dt
            p.x       += p.vx * dt
            p.y       += p.vy * dt
            p.angle   += p.angularV * Double(dt)

            let t      = p.age / p.life
            // fade solo en el último 30 %
            p.opacity  = t < 0.7 ? 1.0 : max(0, 1.0 - (t - 0.7) / 0.3)

            return p.age < p.life ? p : nil
        }
    }
}

// MARK: - Paleta de confeti (top-level para evitar ambiguedad)
private let confettiPalette: [Color] = [
    Color(red: 0.23, green: 0.51, blue: 0.96),  // azul
    Color(red: 0.93, green: 0.28, blue: 0.60),  // rosa
    Color(red: 0.96, green: 0.62, blue: 0.04),  // ámbar
    Color(red: 0.06, green: 0.72, blue: 0.51),  // verde
    Color(red: 0.55, green: 0.36, blue: 0.96),  // violeta
    Color(red: 0.96, green: 0.25, blue: 0.37),  // coral
    .white
]
