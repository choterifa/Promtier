//
//  PromptCard.swift
//  Promtier
//
//  VISTA: Card moderna para mostrar prompts en la lista
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct PromptCard: View {
    let prompt: Prompt
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Indicador de categoría con color
            if let folder = prompt.folder,
               let category = PredefinedCategory.fromString(folder) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(category.color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(category.color)
                }
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .font(.title3)
                    .frame(width: 24, height: 24)
            }
            
            // Contenido principal
            VStack(alignment: .leading, spacing: 8) {
                // Título
                Text(prompt.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Descripción/Contenido
                Text(prompt.content)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Estrella de favorito
            if prompt.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .shadow(
            color: .black.opacity(isHovered ? 0.05 : 0.02),
            radius: isHovered ? 4 : 2,
            x: 0,
            y: isHovered ? 2 : 1
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                onTap()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleTap()
            }
        )
        .onHover { hovering in
            // Optimización: Hover más eficiente
            onHover(hovering)
        }
    }
    
    // Colores dinámicos basados en el estado
    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.12)
        } else if isHovered {
            return Color.gray.opacity(0.08)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
    
    private var cardBorderColor: Color {
        if isSelected {
            return Color.blue
        } else if isHovered {
            return Color.gray.opacity(0.25)
        } else {
            return Color.gray.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PromptCard(
            prompt: Prompt(
                title: "Code Review",
                content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Arquitectura y diseño\n2. Buenas prácticas\n3. Performance\n4. Seguridad\n\n{{codigo}}",
                folder: "Trabajo"
            ),
            isSelected: false,
            isHovered: false,
            onTap: { },
            onDoubleTap: { },
            onHover: { _ in }
        )
        
        PromptCard(
            prompt: Prompt(
                title: "Blog Post Outline",
                content: "Crea un esquema para un blog post sobre {{tema}} con introducción, puntos clave y conclusión.",
                folder: "Contenido"
            ),
            isSelected: true,
            isHovered: false,
            onTap: { },
            onDoubleTap: { },
            onHover: { _ in }
        )
        
        PromptCard(
            prompt: Prompt(
                title: "Email Profesional",
                content: "Asunto: {{asunto}}\n\nCuerpo del email profesional...",
                folder: "Trabajo"
            ),
            isSelected: false,
            isHovered: true,
            onTap: { },
            onDoubleTap: { },
            onHover: { _ in }
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
