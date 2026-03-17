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
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple.opacity(0.2), .blue.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(featureName)
                    .font(.system(size: 20, weight: .bold))
                
                Text("Esta función es exclusiva de Promtier Premium.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            // Lista de beneficios
            VStack(alignment: .leading, spacing: 16) {
                PremiumFeatureRow(
                    icon: "slider.horizontal.3",
                    title: "Variables Avanzadas",
                    description: "Menús desplegables y selectores de fecha nativos en lugar de solo texto."
                )
                
                PremiumFeatureRow(
                    icon: "keyboard.badge.waveform",
                    title: "Snippets Reutilizables",
                    description: "Autocompleta fragmentos de texto enteros con solo escribir '/'"
                )
                
                PremiumFeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Historial de Versiones",
                    description: "Viaja en el tiempo y recupera iteraciones pasadas de tus prompts."
                )
                
                PremiumFeatureRow(
                    icon: "sparkles",
                    title: "Magia Visual (VFX)",
                    description: "Efectos de confeti y partículas al copiar para que el trabajo se sienta vivo."
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            
            Spacer()
            
            // Botones
            VStack(spacing: 12) {
                Button(action: {
                    // Acción para "comprar" - Por ahora abre ajustes para activar
                    // En el futuro: Navegaría a Checkout
                    onCancel?() ?? dismiss()
                }) {
                    Text("Desbloquear Premium")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button("Quizás más Tarde") {
                    onCancel?() ?? dismiss()
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(width: 450, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
