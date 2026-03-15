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
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .shadow(
            color: .black.opacity(isHovered ? 0.1 : 0.05),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .onTapGesture(count: 1, perform: onTap)
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    // Colores dinámicos basados en el estado
    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.8)
        }
    }
    
    private var cardBorderColor: Color {
        if isSelected {
            return Color.blue
        } else if isHovered {
            return Color.gray.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PromptCard(
            prompt: Prompt(
                title: "Code Review",
                content: "Por favor, revisa este código y proporciona feedback constructivo sobre arquitectura y buenas prácticas.",
                description: "Plantilla para revisión de código",
                tags: ["coding", "review"],
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
                description: "Plantilla para blog posts",
                tags: ["writing", "blog"],
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
                description: "Plantilla de email",
                tags: ["email", "profesional"],
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
