//
//  PremiumUpsellView.swift
//  Promtier
//
//  VISTA: Pantalla de bloqueo para funciones Premium
//

import SwiftUI

// Un patrón de fondo sutil inspirado en motivos geométricos indios
struct IndianPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let size: CGFloat = 80
            let cols = Int(geometry.size.width / size) + 2
            let rows = Int(geometry.size.height / size) + 2
            
            ZStack {
                // Fondo oscuro rico (Berenjena/Púrpura Profundo)
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#310A27"), Color(hex: "#120311")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Patrón repetitivo de estilo mandala/floral sutil
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<cols, id: \.self) { col in
                                ZStack {
                                    // Símbolos SF superpuestos para crear un motivo
                                    Image(systemName: "sun.max.fill")
                                        .font(.system(size: 30))
                                        .opacity(0.3)
                                    Image(systemName: "rhombus.fill")
                                        .font(.system(size: 14))
                                        .rotationEffect(.degrees(45))
                                        .opacity(0.8)
                                    Image(systemName: "circle")
                                        .font(.system(size: 40, weight: .thin))
                                        .opacity(0.5)
                                }
                                .foregroundColor(Color(hex: "#E5A93C").opacity(0.04))
                                .frame(width: size, height: size)
                                .offset(x: row % 2 == 0 ? 0 : size / 2)
                            }
                        }
                    }
                }
                
                // Efecto de resplandor (Glow) cálido
                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: "#E5A93C").opacity(0.12), .clear]),
                    center: .top,
                    startRadius: 10,
                    endRadius: 350
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: "#E5A93C").opacity(0.08), .clear]),
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 250
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct PremiumUpsellView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var preferences: PreferencesManager
    
    let featureName: String
    var onCancel: (() -> Void)? = nil
    
    // Gradiente dorado premium
    let goldGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#F9D423"), Color(hex: "#E5A93C"), Color(hex: "#FF4E50")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    let goldTextGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#FDEB71"), Color(hex: "#F8D800")]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        ZStack {
            IndianPatternBackground()
            
            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 12) {
                        // Icono Corona / Premium
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 64, height: 64)
                                .shadow(color: Color(hex: "#E5A93C").opacity(0.2), radius: 10, x: 0, y: 0)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(goldGradient)
                        }
                        .padding(.top, 10)
                        
                        Text("Promtier Pro")
                            .font(.system(size: 26, weight: .black, design: .serif))
                            .foregroundStyle(goldTextGradient)
                            
                        Text("Desbloquea el verdadero poder de Promtier")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#FBECC4").opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 25)
                    .padding(.bottom, 20)
                    
                    Button(action: {
                        onCancel?() ?? dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
                
                // Tarjetas de Características
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        PremiumFeatureCard(
                            icon: "wand.and.stars.inverse",
                            title: "Autocompletado Mágico",
                            description: "La IA genera el título y descripción automáticamente basándose en tu prompt."
                        )
                        
                        PremiumFeatureCard(
                            icon: "text.quote",
                            title: "Snippets Rápidos",
                            description: "Guarda fragmentos de texto y utilízalos en cualquier prompt rápidamente."
                        )
                        
                        PremiumFeatureCard(
                            icon: "slider.horizontal.3",
                            title: "Variables Dinámicas",
                            description: "Rellena espacios en blanco de forma interactiva con soporte para múltiples variables."
                        )
                        
                        PremiumFeatureCard(
                            icon: "cpu",
                            title: "Modelos de IA Avanzados",
                            description: "Accede a las últimas actualizaciones y capacidades con Promtier Pro."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
                
                // Sección de Precio y Botón
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("$14.99")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("USD / pago único")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#E5A93C").opacity(0.8))
                    }
                    
                    Text("Licencia de por vida. Sin suscripciones.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button(action: {
                        if let url = URL(string: "https://promtier.valencia") {
                            NSWorkspace.shared.open(url)
                        }
                        onCancel?() ?? dismiss()
                    }) {
                        HStack {
                            Text("Obtener Licencia Pro")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#1A0516"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#F9D423"), Color(hex: "#E5A93C")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "#E5A93C").opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .background(
                    ZStack {
                        Color.black.opacity(0.3)
                        // Borde superior dorado sutil
                        VStack {
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.clear, Color(hex: "#E5A93C").opacity(0.5), .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                )
            }
        }
        .frame(width: 390, height: 620)
        .background(Color(NSColor.windowBackgroundColor)) // Fallback
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#E5A93C").opacity(0.6), Color(hex: "#E5A93C").opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#E5A93C").opacity(0.15), Color(hex: "#E5A93C").opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#E5A93C").opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "#FDEB71"), Color(hex: "#E5A93C")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "#E5A93C").opacity(0.5), radius: 2, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#FBECC4")) // Tono crema/dorado claro
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}
