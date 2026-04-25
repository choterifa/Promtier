//
//  PremiumUpsellView.swift
//  Promtier
//
//  VISTA: Pantalla de bloqueo para funciones Premium
//

import SwiftUI

struct PremiumUpsellView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var preferences: PreferencesManager
    
    let featureName: String
    var onCancel: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con Gradiente
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#2D1B4E"), Color(hex: "#1A1A2E")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Promtier Pro")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        
                    Text("Desbloquea el verdadero poder de Promtier")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 25)
                
                Button(action: {
                    onCancel?() ?? dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(14)
            }
            
            // Características
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PremiumFeatureRow(
                        icon: "sparkles.rectangle.stack",
                        title: "Autocompletado Mágico",
                        description: "La IA genera el título y descripción automáticamente basándose en tu prompt."
                    )
                    
                    PremiumFeatureRow(
                        icon: "text.quote",
                        title: "Snippets Rápidos",
                        description: "Guarda fragmentos de texto y utilízalos en cualquier prompt rápidamente."
                    )
                    
                    PremiumFeatureRow(
                        icon: "slider.horizontal.3",
                        title: "Variables Dinámicas",
                        description: "Rellena espacios en blanco de forma interactiva con soporte para múltiples variables."
                    )
                    
                    PremiumFeatureRow(
                        icon: "wand.and.stars",
                        title: "Modelos de IA Avanzados",
                        description: "Accede a las últimas actualizaciones y capacidades con Promtier Pro."
                    )
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
            }
            
            Divider().opacity(0.5)
            
            // Sección de Precio y Botón
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$14.99")
                        .font(.system(size: 28, weight: .bold))
                    Text("USD / pago único")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("Licencia de por vida. Sin suscripciones.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = URL(string: "https://promtier.valencia") {
                        NSWorkspace.shared.open(url)
                    }
                    onCancel?() ?? dismiss()
                }) {
                    Text("Obtener Licencia Pro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#FF5E3A"), Color(hex: "#FF2A6D")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(hex: "#FF2A6D").opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 380, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
