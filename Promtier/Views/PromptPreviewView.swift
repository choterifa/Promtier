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
    @State private var showingFullScreenImageURL: URL? = nil
    @State private var isVisible = false
    @State private var showcaseImagePaths: [String] = []
    @State private var isLoadingImages: Bool = false
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    /// Binding para notificar al padre cuando una hoja secundaria está abierta
    @Binding var isFullScreenImageOpen: Bool
    
    init(prompt: Prompt, isFullScreenImageOpen: Binding<Bool> = .constant(false)) {
        self.prompt = prompt
        self._isFullScreenImageOpen = isFullScreenImageOpen
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra de color temática superior
            if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
                Rectangle()
                    .fill(category.color.opacity(0.8))
                    .frame(height: 3)
            }
            
            headerView
            
            // Separador sutil
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido Estilizado con Imágenes Prioritarias
            contentScrollView
        }
        .frame(width: 500, height: 400)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.4)
            }
        )
        .sheet(item: Binding(
            get: { showingFullScreenImageURL.map { IdentifiableURL(value: $0) } },
            set: { showingFullScreenImageURL = $0?.value }
        )) { item in
            FullScreenImageView(imageURL: item.value)
                .onAppear { isFullScreenImageOpen = true }
                .onDisappear { 
                    isFullScreenImageOpen = false
                    MenuBarManager.shared.fixTransientState()
                }
        }
        .onAppear {
            isVisible = true
            showcaseImagePaths = prompt.showcaseImagePaths
        }
        .onDisappear {
            isVisible = false
        }
        .task(id: prompt.id) {
            guard showcaseImagePaths.isEmpty, prompt.showcaseImageCount > 0 else { return }
            if isLoadingImages { return }
            isLoadingImages = true
            let paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            await MainActor.run {
                self.showcaseImagePaths = paths
                self.isLoadingImages = false
            }
        }
    }
    
    private var headerView: some View {
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
                    .lineLimit(2)
                
                if let folder = prompt.folder {
                    Text(folder)
                        .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                        .textCase(.uppercase)
                }
            }
            
            Spacer()
            
            // Acciones a la derecha
            HStack(spacing: 8) {
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
                
                if prompt.showcaseImageCount > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            preferences.previewImagesFirst.toggle()
                        }
                        HapticService.shared.playLight()
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
    
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Galería al inicio si la preferencia es true
                if preferences.previewImagesFirst && !showcaseImagePaths.isEmpty {
                    showcaseGallery
                    Divider().padding(.top, 4).padding(.bottom, 8) // Espacio reducido
                }
                
                Text(highlightContent(prompt.content))
                    .font(.system(size: 16 * preferences.fontSize.scale, design: .rounded))
                    .lineSpacing(6)
                    .foregroundColor(.primary.opacity(0.9))
                    .textSelection(.enabled)
                
                // Prompt Negativo (Si existe)
                if let negative = prompt.negativePrompt, !negative.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                            Text("negative_prompt".localized(for: preferences.language).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)
                            
                            Spacer()
                            
                            Button(action: {
                                ClipboardService.shared.copyToClipboard(negative)
                                if preferences.soundEnabled {
                                    SoundService.shared.playNegativeCopySound()
                                }
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(negative)
                            .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color.red.opacity(0.03))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                }
                
                // Prompts Alternativos (Si existen)
                if !prompt.alternatives.isEmpty {
                    ForEach(Array(prompt.alternatives.enumerated()), id: \.offset) { index, alternative in
                        if !alternative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green.opacity(0.8))
                                    Text("\("alternative".localized(for: preferences.language).uppercased()) #\(index + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        ClipboardService.shared.copyToClipboard(alternative)
                                        if preferences.soundEnabled {
                                            SoundService.shared.playAlternativeCopySound()
                                        }
                                        HapticService.shared.playLight()
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundColor(.green.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(alternative)
                                    .font(.system(size: 13 * preferences.fontSize.scale, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .padding(12)
                                    .background(Color.green.opacity(0.03))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .padding(.top, 8)
                        }
                    }
                } else if let alternative = prompt.alternativePrompt, !alternative.isEmpty {
                    // Fallback para datos antiguos aún no migrados visualmente en el modelo
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green.opacity(0.8))
                            Text("alternative_prompt".localized(for: preferences.language).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)
                            
                            Spacer()
                            
                            Button(action: {
                                ClipboardService.shared.copyToClipboard(alternative)
                                if preferences.soundEnabled {
                                    SoundService.shared.playAlternativeCopySound()
                                }
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(alternative)
                            .font(.system(size: 13 * preferences.fontSize.scale, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(12)
                            .background(Color.green.opacity(0.03))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                }
                
                // Galería al final si la preferencia es false
                if !preferences.previewImagesFirst && !showcaseImagePaths.isEmpty {
                    Divider().padding(.top, 12).padding(.bottom, 8) // Separador para cuando está abajo
                    showcaseGallery
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Subviews
    
    private var showcaseGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("prompt_results")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(showcaseImagePaths.enumerated()), id: \.offset) { index, relativePath in
                        let url = ImageStore.shared.url(forRelativePath: relativePath)
                        GalleryThumbnail(url: url, promptId: prompt.id, index: index, relativePath: relativePath) {
                            showingFullScreenImageURL = url
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
        }
    }

    // Sub-componente para la miniatura con hover
    private struct GalleryThumbnail: View {
        let url: URL
        let promptId: UUID
        let index: Int
        let relativePath: String
        let action: () -> Void
        
        @State private var isHovered = false
        
                var body: some View {
                    DownsampledImageURLView(
                        imageURL: url,
                        cacheKey: "\(promptId.uuidString):preview:\(index):900:\(relativePath)",
                        maxPixelSize: 900,
                        contentMode: .fill
                    )
                    .frame(width: 280, height: 180, alignment: .top)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        // Icono de lupa al hacer hover (Esquina Inferior Derecha)
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.1), radius: 4)
        
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary.opacity(0.7))
                        }
                        .padding(10)
                        .opacity(isHovered ? 1 : 0)
                        .scaleEffect(isHovered ? 1 : 0.8)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
                    .onTapGesture {
                        action()
                    }
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isHovered = hovering
                        }
                    }
                    .task {
                        // Pre-warm the image decode to make space preview faster
                        await ImageDecodeThrottler.prewarm(url: url, cacheKey: "\(promptId.uuidString):preview:\(index):900:\(relativePath)", maxPixelSize: 900)
                    }
                }    }
    
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
        
        let themeColor: Color = {
            if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
                return category.color
            }
            return .blue
        }()
        
        // 1. Resaltado de Brackets (Color categoría)
        let bracketPattern = "[\\{\\}\\[\\]\\(\\)]"
        if let bracketRegex = try? NSRegularExpression(pattern: bracketPattern, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = bracketRegex.matches(in: text, options: [], range: range)
            for match in matches {
                if let range = Range(match.range, in: attrString) {
                    attrString[range].foregroundColor = themeColor.opacity(0.8)
                }
            }
        }
        
        // 2. Resaltado de Variables (Estilo Promtier - Color categoría)
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

#Preview {
    let samplePrompt = Prompt(
        title: "Code Review",
        content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Arquitectura y diseño\n2. Buenas prácticas\n3. Performance\n4. Seguridad\n\n{{codigo}}",
        folder: nil
    )
    
    PromptPreviewView(prompt: samplePrompt)
        .environmentObject(PreferencesManager.shared)
        .environmentObject(PromptService.shared)
}
