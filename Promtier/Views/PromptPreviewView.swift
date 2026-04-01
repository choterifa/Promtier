//
//  PromptPreviewView.swift
//  Promtier
//
//  VISTA: Popover de preview estilo Finder para prompts
//  Created by Carlos on 15/03/26.
//

import AppKit
import SwiftUI

struct PromptPreviewView: View {
    private enum PreviewImageProfile {
        static let mediumPixelSize = 1120
        static let thumbnailOnlyPixelSize = 640
    }

    let prompt: Prompt
    let prefetchedShowcasePaths: [String]?
    @State private var showingFullScreenImageURL: URL? = nil
    @State private var showingFullScreenImageData: Data? = nil
    @State private var isVisible = false
    @State private var showcaseImagePaths: [String] = []
    @State private var isLoadingImages: Bool = false
    @State private var legacyFallbackImageData: Data? = nil
    @State private var cachedAttributedContent: AttributedString? = nil
    @State private var cachedContentTask: Task<Void, Never>? = nil
    @Environment(\.colorScheme) private var colorScheme 
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    /// Binding para notificar al padre cuando una hoja secundaria está abierta
    @Binding var isFullScreenImageOpen: Bool
    
    var onUse: (() -> Void)?

    private var templateVariableCount: Int {
        PromptCardTextCache.shared.variableCount(for: prompt)
    }

    private struct ShowcaseEntry: Identifiable {
        let id: String
        let index: Int
        let url: URL?
        let relativePath: String?
        let thumbnailData: Data?
    }

    private var showcaseEntries: [ShowcaseEntry] {
        let total = max(showcaseImagePaths.count, prompt.showcaseThumbnails.count)
        guard total > 0 || legacyFallbackImageData != nil else { return [] }

        var entries: [ShowcaseEntry] = []
        entries.reserveCapacity(max(1, total))

        for index in 0..<total {
            let path = showcaseImagePaths.indices.contains(index) ? showcaseImagePaths[index] : nil
            let thumb = prompt.showcaseThumbnails.indices.contains(index) ? prompt.showcaseThumbnails[index] : nil
            guard path != nil || thumb != nil else { continue }

            entries.append(
                ShowcaseEntry(
                    id: "\(prompt.id.uuidString)-\(index)-\(path ?? "thumb-only")",
                    index: index,
                    url: path.map { ImageStore.shared.url(forRelativePath: $0) },
                    relativePath: path,
                    thumbnailData: thumb
                )
            )
        }

        if entries.isEmpty, let legacyFallbackImageData {
            entries.append(
                ShowcaseEntry(
                    id: "\(prompt.id.uuidString)-legacy-fallback",
                    index: 0,
                    url: nil,
                    relativePath: nil,
                    thumbnailData: legacyFallbackImageData
                )
            )
        }

        return entries
    }

    private var shouldDisplayGallery: Bool {
        !showcaseEntries.isEmpty || (prompt.showcaseImageCount > 0 && isLoadingImages)
    }

    private var resolvedCategoryColor: Color {
        if let folderName = prompt.folder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .blue
        }
        return .blue
    }
    
    private var resolvedCategoryIcon: String {
        if let customIcon = prompt.icon {
            return customIcon
        }
        if let folderName = prompt.folder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return customFolder.icon ?? "folder.fill"
            }
            return PredefinedCategory.fromString(folderName)?.icon ?? "doc.text.fill"
        }
        return "doc.text.fill"
    }

    private var previewThemeColor: PromptPreviewThemeColor {
        return PromptPreviewThemeColor(NSColor(resolvedCategoryColor))
    }
    
    init(
        prompt: Prompt,
        prefetchedShowcasePaths: [String]? = nil,
        isFullScreenImageOpen: Binding<Bool> = .constant(false),
        onUse: (() -> Void)? = nil
    ) {
        self.prompt = prompt
        self.prefetchedShowcasePaths = prefetchedShowcasePaths
        self._isFullScreenImageOpen = isFullScreenImageOpen
        self.onUse = onUse
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra de color temática superior
            Rectangle()
                .fill(resolvedCategoryColor.opacity(0.8))
                .frame(height: 3)
            
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
        .sheet(
            isPresented: Binding(
                get: { showingFullScreenImageData != nil },
                set: { isPresented in
                    if !isPresented {
                        showingFullScreenImageData = nil
                    }
                }
            )
        ) {
            if let data = showingFullScreenImageData {
                FullScreenImageView(imageData: data)
                    .onAppear { isFullScreenImageOpen = true }
                    .onDisappear {
                        isFullScreenImageOpen = false
                        MenuBarManager.shared.fixTransientState()
                    }
            }
        }
        .onAppear {
            isVisible = true
            showcaseImagePaths = prefetchedShowcasePaths ?? prompt.showcaseImagePaths
            updateCachedContent()
        }
        .onDisappear {
            isVisible = false
            cachedContentTask?.cancel()
        }
        .onChange(of: prompt.id) { _, _ in
            updateCachedContent()
        }
        .onChange(of: preferences.fontSize.scale) { _, _ in
            updateCachedContent()
        }
        .onChange(of: colorScheme) { _, _ in
            updateCachedContent()
        }
        .task(id: prompt.id) {
            // Cargar paths si no están ya en el objeto (CoreData fault)
            if showcaseImagePaths.isEmpty && prompt.showcaseImageCount > 0 {
                if isLoadingImages { return }
                isLoadingImages = true
                let paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
                var legacyFallback: Data? = nil
                if paths.isEmpty {
                    legacyFallback = await promptService.fetchShowcaseImages(byId: prompt.id).first
                }
                await MainActor.run {
                    self.showcaseImagePaths = paths
                    self.legacyFallbackImageData = legacyFallback
                    self.isLoadingImages = false
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 15) {
            // Icono de categoría o personalizado
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(resolvedCategoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: resolvedCategoryIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(resolvedCategoryColor)
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
                if templateVariableCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 10))
                        Text("\(templateVariableCount)")
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
                
                // Botón de Copiar Principal
                Button(action: {
                    if let onUse = onUse {
                        onUse()
                    } else {
                        ClipboardService.shared.copyToClipboard(prompt.content)
                        if preferences.soundEnabled {
                            SoundService.shared.playSuccessSound()
                        }
                        HapticService.shared.playLight()
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("copy_to_clipboard".localized(for: preferences.language))
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
                if preferences.previewImagesFirst && shouldDisplayGallery {
                    showcaseGallery
                    Divider().padding(.top, 4).padding(.bottom, 8) // Espacio reducido
                }
                
                if let attributedContent = cachedAttributedContent {
                    Text(attributedContent)
                        .font(.system(size: 16 * preferences.fontSize.scale, design: .rounded))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.9))
                        .textSelection(.enabled)
                } else {
                    // Fallback mientras se carga o falla
                    Text(prompt.content)
                        .font(.system(size: 16 * preferences.fontSize.scale, design: .rounded))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.9))
                        .textSelection(.enabled)
                }
                
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
                if !preferences.previewImagesFirst && shouldDisplayGallery {
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
        return VStack(alignment: .leading, spacing: 8) {
            
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("prompt_results")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(showcaseEntries) { entry in
                        if let url = entry.url, let relativePath = entry.relativePath {
                            GalleryThumbnail(
                                url: url,
                                promptId: prompt.id,
                                index: entry.index,
                                relativePath: relativePath,
                                thumbnailData: entry.thumbnailData
                            ) {
                                if ImageStore.shared.fileExists(relativePath: relativePath) {
                                    showingFullScreenImageURL = url
                                    return
                                }
                                if let thumb = entry.thumbnailData {
                                    // Fallback de seguridad para no romper la apertura del preview.
                                    showingFullScreenImageData = thumb
                                    return
                                }
                                Task {
                                    let resolvedPaths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
                                    await MainActor.run {
                                        if !resolvedPaths.isEmpty {
                                            showcaseImagePaths = resolvedPaths
                                        }
                                        if resolvedPaths.indices.contains(entry.index) {
                                            let resolvedURL = ImageStore.shared.url(forRelativePath: resolvedPaths[entry.index])
                                            showingFullScreenImageURL = resolvedURL
                                        }
                                    }
                                }
                            }
                        } else if let thumbnailData = entry.thumbnailData {
                            GalleryThumbnailData(
                                promptId: prompt.id,
                                index: entry.index,
                                thumbnailData: thumbnailData
                            ) {
                                Task {
                                    let resolvedPaths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
                                    await MainActor.run {
                                        if !resolvedPaths.isEmpty {
                                            showcaseImagePaths = resolvedPaths
                                        }
                                        if resolvedPaths.indices.contains(entry.index) {
                                            let resolvedURL = ImageStore.shared.url(forRelativePath: resolvedPaths[entry.index])
                                            showingFullScreenImageURL = resolvedURL
                                        } else {
                                            // Fallback de seguridad (solo si aún no hay path en disco).
                                            showingFullScreenImageData = thumbnailData
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if showcaseEntries.isEmpty && isLoadingImages {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 280, height: 180)
                            .overlay {
                                ProgressView()
                                    .controlSize(.regular)
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
        let thumbnailData: Data?
        let action: () -> Void
        
        @State private var isHovered = false
        @State private var verticalOffset: CGFloat = 0
        
        var body: some View {
            DownsampledImageURLView(
                imageURL: url,
                cacheKey: "\(promptId.uuidString):preview:\(index):\(PreviewImageProfile.mediumPixelSize):\(relativePath)",
                maxPixelSize: PreviewImageProfile.mediumPixelSize,
                contentMode: .fill,
                thumbnailData: thumbnailData
            )
            .scaleEffect(1.15)
            .offset(y: verticalOffset)
            .frame(width: 280, height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                // Solo lupa, reducida a 22px
                Button(action: {
                    action()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.1), radius: 4)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
                .opacity(isHovered ? 1 : 0)
                .scaleEffect(isHovered ? 1 : 0.8)
            }
            .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
            // Captura scroll del trackpad a nivel AppKit — overlay para recibir eventos
            .overlay(
                ScrollWheelCapture { delta in
                    let newOffset = verticalOffset + delta * 0.6
                    withAnimation(.interactiveSpring()) {
                        verticalOffset = max(-80, min(80, newOffset))
                    }
                }
                .frame(width: 280, height: 180)
            )
            .onTapGesture(count: 2) {
                action()
            }
            .onTapGesture {
                action()
            }
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
        }
    }

    private struct GalleryThumbnailData: View {
        let promptId: UUID
        let index: Int
        let thumbnailData: Data
        let action: () -> Void

        @State private var isHovered = false
        @State private var verticalOffset: CGFloat = 0

        var body: some View {
            DownsampledImageView(
                imageData: thumbnailData,
                cacheKey: "\(promptId.uuidString):preview:thumb-only:\(index):\(PreviewImageProfile.thumbnailOnlyPixelSize)",
                maxPixelSize: PreviewImageProfile.thumbnailOnlyPixelSize,
                contentMode: .fill
            )
            .scaleEffect(1.15)
            .offset(y: verticalOffset)
            .frame(width: 280, height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                Button(action: { action() }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.1), radius: 4)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .padding(10)
                .opacity(isHovered ? 1 : 0)
                .scaleEffect(isHovered ? 1 : 0.8)
            }
            .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
            .overlay(
                ScrollWheelCapture { delta in
                    let newOffset = verticalOffset + delta * 0.6
                    withAnimation(.interactiveSpring()) {
                        verticalOffset = max(-80, min(80, newOffset))
                    }
                }
                .frame(width: 280, height: 180)
            )
            .onTapGesture(count: 2) {
                action()
            }
            .onTapGesture {
                action()
            }
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    // MARK: - ScrollWheelCapture (AppKit bridge para trackpad)
    /// Captura eventos de scroll del trackpad directamente en AppKit,
    /// evitando que el ScrollView padre los consuma primero.
    private struct ScrollWheelCapture: NSViewRepresentable {
        let onScroll: (CGFloat) -> Void
        
        func makeNSView(context: Context) -> ScrollCaptureNSView {
            let view = ScrollCaptureNSView()
            view.onScroll = onScroll
            return view
        }
        
        func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {
            nsView.onScroll = onScroll
        }
    }
    
    final class ScrollCaptureNSView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        
        override var acceptsFirstResponder: Bool { false }
        
        // Reenviar clicks al responder chain para que SwiftUI los maneje
        override func mouseDown(with event: NSEvent) {
            nextResponder?.mouseDown(with: event)
        }
        override func mouseUp(with event: NSEvent) {
            nextResponder?.mouseUp(with: event)
        }
        
        override func scrollWheel(with event: NSEvent) {
            // Solo procesar si el usuario tiene activada la preferencia
            guard PreferencesManager.shared.enableTrackpadCarousel else {
                nextResponder?.scrollWheel(with: event)
                return
            }
            
            guard event.phase != [] || event.momentumPhase != [] else {
                super.scrollWheel(with: event)
                return
            }
            let dx = abs(event.scrollingDeltaX)
            let dy = abs(event.scrollingDeltaY)
            // Solo procesar si el gesto es predominantemente vertical
            // Si es más horizontal que vertical, dejar pasar al siguiente responder
            if dy > dx {
                onScroll?(event.scrollingDeltaY)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }

    
    // MARK: - Helpers
    
    private func updateCachedContent() {
        let scale = preferences.fontSize.scale

        let key = PromptPreviewTextCache.shared.cacheKey(
            promptId: prompt.id,
            modifiedAt: prompt.modifiedAt,
            scale: scale,
            interfaceStyle: previewInterfaceStyle
        )
        let promptSnapshot = prompt
        let themeColor = previewThemeColor
        let interfaceStyle = previewInterfaceStyle

        cachedContentTask?.cancel()
        cachedContentTask = Task(priority: .utility) {
            let converted: AttributedString? = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let source = PromptPreviewTextCache.shared.cachedAttributedString(forKey: key)
                        ?? PromptPreviewTextCache.shared.highlightedString(
                            for: promptSnapshot,
                            themeColor: themeColor,
                            scale: scale,
                            interfaceStyle: interfaceStyle
                        )
                    let converted = try? AttributedString(source, including: \.appKit)
                    continuation.resume(returning: converted)
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.cachedAttributedContent = converted
            }
        }
    }

    private var previewInterfaceStyle: PromptPreviewInterfaceStyle {
        colorScheme == .dark ? .dark : .light
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
