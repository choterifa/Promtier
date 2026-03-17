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
                // Icono de categoría o personalizado
                if let iconName = prompt.icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((prompt.folder != nil ? PredefinedCategory.fromString(prompt.folder!)?.color ?? .blue : .blue).opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(prompt.folder != nil ? PredefinedCategory.fromString(prompt.folder!)?.color ?? .blue : .blue)
                    }
                } else if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
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
                
                // Toggle para posición de imágenes (Flecha)
                if !prompt.showcaseImages.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            preferences.previewImagesFirst.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: preferences.previewImagesFirst ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Image(systemName: "photo")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help(preferences.previewImagesFirst ? "Mostrar fotos al final" : "Mostrar fotos primero")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Separador sutil
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido Estilizado con Imágenes Prioritarias
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Galería al inicio si la preferencia es true
                    if preferences.previewImagesFirst && !prompt.showcaseImages.isEmpty {
                        showcaseGallery
                        Divider().padding(.top, 4).padding(.bottom, 8) // Espacio reducido
                    }
                    
                    Text(highlightContent(prompt.content))
                        .font(.system(size: 16 * preferences.fontSize.scale, design: .rounded))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.9))
                        .textSelection(.enabled)
                    
                    // Galería al final si la preferencia es false
                    if !preferences.previewImagesFirst && !prompt.showcaseImages.isEmpty {
                        Divider().padding(.top, 12).padding(.bottom, 8) // Separador para cuando está abajo
                        showcaseGallery
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
    
    // MARK: - Subviews
    
    private var showcaseGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("RESULTADOS DEL PROMPT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(prompt.showcaseImages, id: \.self) { imageData in
                        if let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 140, alignment: .top)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func splitContent(_ content: String) -> (firstBlock: String, secondBlock: String) {
        let paragraphs = content.components(separatedBy: "\n\n")
        if paragraphs.count <= 2 {
            return (content, "")
        }
        
        let firstBlock = paragraphs.prefix(2).joined(separator: "\n\n")
        let secondBlock = paragraphs.dropFirst(2).joined(separator: "\n\n")
        return (firstBlock, secondBlock)
    }
    
    private func highlightContent(_ text: String) -> AttributedString {
        var attrString = AttributedString(text)
        let pattern = "\\{\\{([^}]+)\\}\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attrString
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
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
