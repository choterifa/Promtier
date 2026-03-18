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
                
                Text("premium_exclusive_message".localized(for: preferences.language))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            // Lista de beneficios
            VStack(alignment: .leading, spacing: 16) {
                PremiumFeatureRow(
                    icon: "slider.horizontal.3",
                    title: "advanced_variables".localized(for: preferences.language),
                    description: "advanced_variables_desc".localized(for: preferences.language)
                )
                
                PremiumFeatureRow(
                    icon: "/",
                    title: "reusable_snippets".localized(for: preferences.language),
                    description: "reusable_snippets_desc".localized(for: preferences.language)
                )
                
                PremiumFeatureRow(
                    icon: "clock.arrow.circlepath",
                    title: "version_history".localized(for: preferences.language),
                    description: "version_history_desc".localized(for: preferences.language)
                )
                
                PremiumFeatureRow(
                    icon: "sparkles",
                    title: "visual_vfx".localized(for: preferences.language),
                    description: "visual_vfx_desc".localized(for: preferences.language)
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
                    Text("unlock_premium".localized(for: preferences.language))
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
                
                Button("maybe_later".localized(for: preferences.language)) {
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
            if icon == "/" {
                // Icono especial para Snippets estilo botón
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("/")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
            } else {
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
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
    }
}
