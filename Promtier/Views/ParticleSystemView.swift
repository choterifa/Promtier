//
//  ParticleSystemView.swift
//  Promtier
//
//  COMPONENTE: Sistema de Partículas para efectos visuales (Premium)
//

import SwiftUI

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var scale: CGFloat
    var opacity: Double
    var color: Color
    var age: Double   // segundos transcurridos
    let life: Double  // vida máxima en segundos
}

struct ParticleSystemView: View {
    let accentColor: Color
    
    @State private var particles: [Particle] = []
    @State private var lastTick: Date = Date()
    
    private static let burst = 55  // partículas emitidas de golpe
    private static let gravity: CGFloat = 180 // px/s²
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                Canvas { drawCtx, size in
                    for p in particles {
                        let r = 6.0 * p.scale
                        let rect = CGRect(x: p.x - r/2, y: p.y - r/2, width: r, height: r)
                        var c = drawCtx
                        c.opacity = max(0, p.opacity)
                        c.fill(Path(ellipseIn: rect), with: .color(p.color))
                    }
                }
                .onChange(of: ctx.date) { newDate in
                    let dt = newDate.timeIntervalSince(lastTick)
                    lastTick = newDate
                    tick(dt: dt)
                }
                .onAppear {
                    emit(at: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                }
            }
        }
        // Ignora todos los toques — es solo decorativo
        .allowsHitTesting(false)
    }
    
    // MARK: - Lógica
    
    private func emit(at center: CGPoint) {
        var batch: [Particle] = []
        
        for _ in 0..<Self.burst {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 80...280)
            
            let colors: [Color] = [accentColor, accentColor.opacity(0.7), .white, accentColor.opacity(0.5)]
            
            batch.append(Particle(
                x:       center.x + CGFloat.random(in: -15...15),
                y:       center.y + CGFloat.random(in: -15...15),
                vx:      CGFloat(cos(angle)) * speed,
                vy:      CGFloat(sin(angle)) * speed - CGFloat.random(in: 60...140),
                scale:   CGFloat.random(in: 0.4...1.4),
                opacity: Double.random(in: 0.8...1.0),
                color:   colors.randomElement()!,
                age:     0,
                life:    Double.random(in: 0.6...1.4)
            ))
        }
        
        particles = batch
    }
    
    private func tick(dt: TimeInterval) {
        guard !particles.isEmpty else { return }
        
        let dt = CGFloat(min(dt, 0.05)) // cap a 50ms para evitar saltos
        
        particles = particles.compactMap { var p = $0
            p.age  += Double(dt)
            p.vy   += Self.gravity * dt
            p.x    += p.vx * dt
            p.y    += p.vy * dt
            p.opacity = 1.0 - (p.age / p.life)
            return p.age < p.life ? p : nil
        }
    }
}
