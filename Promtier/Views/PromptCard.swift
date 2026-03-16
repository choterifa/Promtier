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
    
    @EnvironmentObject var preferences: PreferencesManager
    
    private var highlightedContent: AttributedString {
        var attrString = AttributedString(prompt.content)
        let pattern = "\\{\\{([^}]+)\\}\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attrString
        }
        
        let range = NSRange(prompt.content.startIndex..<prompt.content.endIndex, in: prompt.content)
        let matches = regex.matches(in: prompt.content, options: [], range: range)
        
        // Aplicar estilos de atrás hacia adelante para no romper los índices (aunque AttributedString maneja rangos, es buena práctica)
        for match in matches.reversed() {
            if let range = Range(match.range, in: attrString) {
                attrString[range].foregroundColor = .blue
                attrString[range].font = .system(size: 13 * preferences.fontSize.scale, weight: .bold)
            }
        }
        
        return attrString
    }
    
    private var variableCount: Int {
        prompt.extractTemplateVariables().count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icono de categoría refinado
            if let folder = prompt.folder,
               let category = PredefinedCategory.fromString(folder) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(category.color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(category.color)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Texto detallado
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.system(size: 15 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
                
                Text(highlightedContent)
                    .font(.system(size: 13 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Indicadores de estado
            HStack(spacing: 12) {
                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                        .shadow(color: .yellow.opacity(0.3), radius: 2)
                }
                
                if prompt.useCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 8))
                        Text("\(prompt.useCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                }
                
                if variableCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 8))
                        Text("\(variableCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.blue.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                if isHovered || isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary.opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.05 : 0.0), radius: 8, y: 4)
        .contentShape(Rectangle())
        // USAR BUTTON PARA RESPUESTA INSTANTÁNEA (Sin delay de doble clic)
        .onTapGesture {
            onTap()
        }
        // GESTO SIMULTÁNEO PARA EL DOBLE CLIC
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onDoubleTap()
            }
        )
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    // Colores dinámicos Premium
    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.05)
        } else if isHovered {
            return Color.primary.opacity(0.04)
        } else {
            return Color.primary.opacity(0.02)
        }
    }
    
    private var cardBorderColor: Color {
        if isSelected {
            return Color.blue.opacity(0.3)
        } else if isHovered {
            return Color.primary.opacity(0.08)
        } else {
            return Color.primary.opacity(0.04)
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
