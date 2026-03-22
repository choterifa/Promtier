//
//  GhostTipView.swift
//  Promtier
//
//  VISTA: Consejos flotantes sutiles para descubrir funciones
//

import SwiftUI

struct GhostTip: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcut: String
}

struct GhostTipView: View {
    let tip: GhostTip
    var onDismiss: () -> Void
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(.system(size: 12, weight: .bold))
                Text(tip.shortcut)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 0
                    offset = -10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                // Luz de fondo (Glow) expandida para separación visual máxima
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.15))
                    .blur(radius: 15)
                    .offset(y: 4)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                opacity = 1
                offset = 0
            }
            
            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 0
                    offset = -20
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onDismiss()
                }
            }
        }
    }
}
