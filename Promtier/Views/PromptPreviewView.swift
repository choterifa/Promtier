//
//  PromptPreviewView.swift
//  Promtier
//
//  VISTA: Popover de preview estilo Finder para prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct PromptPreviewView: View {
    let prompt: Prompt
    @State private var isVisible = false
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium
            HStack(spacing: 15) {
                // Icono de categoría
                if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(category.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(category.color)
                    }
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue.opacity(0.8))
                        .frame(width: 36, height: 36)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: 18 * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let folder = prompt.folder {
                        Text(folder)
                            .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                            .textCase(.uppercase)
                    }
                }
                
                Spacer()
                
                // Badge de variables si tiene
                if prompt.hasTemplateVariables() {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 10))
                        Text("\(prompt.extractTemplateVariables().count)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Separador sutil
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido Estilizado
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(highlightedContent)
                        .font(.system(size: 16 * preferences.fontSize.scale, design: .rounded))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.9))
                        .textSelection(.enabled)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Footer con atajos de ayuda
            HStack {
                Text("Presiona **Espacio** para cerrar")
                Spacer()
                Text("**Esc** también funciona")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.5))
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 400)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.4)
            }
        )
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
    
    // Contenido resaltado similar a PromptCard
    private var highlightedContent: AttributedString {
        var attrString = AttributedString(prompt.content)
        let pattern = "\\{\\{([^}]+)\\}\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attrString
        }
        
        let range = NSRange(prompt.content.startIndex..<prompt.content.endIndex, in: prompt.content)
        let matches = regex.matches(in: prompt.content, options: [], range: range)
        
        for match in matches.reversed() {
            if let range = Range(match.range, in: attrString) {
                attrString[range].foregroundColor = .blue
                attrString[range].font = .system(size: 16 * preferences.fontSize.scale, weight: .bold)
                attrString[range].backgroundColor = Color.blue.opacity(0.08)
            }
        }
        
        return attrString
    }
}

// Helper para el efecto glassmorphism
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    let samplePrompt = Prompt(
        title: "Code Review",
        content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Arquitectura y diseño\n2. Buenas prácticas\n3. Performance\n4. Seguridad\n\n{{codigo}}",
        folder: nil
    )
    
    PromptPreviewView(prompt: samplePrompt)
}
