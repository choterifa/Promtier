//
//  PromptGridCard.swift
//  Promtier
//
//  VISTA: Card tipo grid (estilo RemNote) para mostrar prompts con imágenes y más detalles
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PromptGridCard: View {
    let prompt: Prompt
    let precomputedCategoryColor: Color
    let isPerformanceMode: Bool
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: (() -> Void)?
    let onHover: (Bool) -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var imageStore: ImageStore
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @State private var isTargetedForDrop = false
    @State private var fallbackShowcasePath: String? = nil
    @State private var isGlowAnimating = false
    @State private var isLocallyHovered = false
    @State private var isAspectFit = false
    @State private var currentImageIndex = 0
    @State private var carouselScrollAccumulator: CGFloat = 0
    @State private var carouselDirection: Int = 1 // 1 = forward (right), -1 = backward (left)
    @State private var highlightedContentCache: AttributedString = AttributedString("")
    @State private var highlightedContentCacheKey: String = ""
    @State private var plainSnippetCache: String = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    private func refreshHighlightedContentCacheIfNeeded() {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        let maxCharacters = isPerformanceMode ? 180 : 250
        let key = "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):\(Int(preferences.fontSize.scale * 100)):" +
            "\(interfaceStyle == .dark ? "d" : "l"):" +
            "\(categoryNSColor.hexString):\(isPerformanceMode ? "p" : "n")"

        guard highlightedContentCacheKey != key else { return }
        highlightedContentCacheKey = key

        let cached = PromptCardTextCache.shared.highlightedSnippet(
            for: prompt,
            maxCharacters: maxCharacters,
            categoryColor: categoryNSColor,
            scale: preferences.fontSize.scale,
            interfaceStyle: interfaceStyle
        )
        highlightedContentCache = AttributedString(cached)
        plainSnippetCache = String(prompt.content.prefix(maxCharacters))
    }

    private var highlightedContentRefreshToken: String {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        return "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):\(Int(preferences.fontSize.scale * 100)):" +
            "\(interfaceStyle == .dark ? "d" : "l"):" +
            "\(categoryNSColor.hexString):\(isPerformanceMode ? "p" : "n")"
    }
    
    private var variableCount: Int { PromptCardTextCache.shared.variableCount(for: prompt) }
    
    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : Color.blue
    }

    private var hoverEffectsEnabled: Bool {
        !isPerformanceMode
    }

    private var effectiveHover: Bool {
        hoverEffectsEnabled && (isHovered || isLocallyHovered)
    }

    private var snippetView: some View {
        Group {
            if isPerformanceMode {
                Text(plainSnippetCache)
            } else {
                Text(highlightedContentCache)
            }
        }
        .font(.system(size: 13 * preferences.fontSize.scale))
        .foregroundColor(.secondary.opacity(0.9))
    }
    
    private var isRecommended: Bool {
        guard let activeApp = promptService.activeAppBundleID else { return false }
        return prompt.targetAppBundleIDs.contains(activeApp)
    }
    
    private var currentCategoryColor: Color {
        precomputedCategoryColor
    }

    @ViewBuilder
    private var recommendedBadge: some View {
        if isRecommended, let activeApp = promptService.activeAppBundleID {
            HStack(spacing: 3) {
                if let icon = AppInfoCache.getIcon(for: activeApp) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 11, height: 11)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8, weight: .bold))
                }

                Text(AppInfoCache.getName(for: activeApp))
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.purple.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    private var previewThumbnailData: Data? {
        prompt.showcaseThumbnails.first
    }

    private var previewRelativePath: String? {
        prompt.showcaseImagePaths.first ?? fallbackShowcasePath
    }

    private var hasPreviewImage: Bool {
        previewThumbnailData != nil || previewRelativePath != nil
    }

    init(
        prompt: Prompt,
        precomputedCategoryColor: Color = .blue,
        isPerformanceMode: Bool = false,
        isSelected: Bool,
        isHovered: Bool,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onCopy: (() -> Void)?,
        onHover: @escaping (Bool) -> Void
    ) {
        self.prompt = prompt
        self.precomputedCategoryColor = precomputedCategoryColor
        self.isPerformanceMode = isPerformanceMode
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onCopy = onCopy
        self.onHover = onHover
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Title and Category
            HStack(alignment: .top) {
                if batchService.isSelectionModeActive {
                    Button(action: {
                        batchService.toggleSelection(for: prompt.id)
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: batchService.selectedPromptIds.contains(prompt.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(batchService.selectedPromptIds.contains(prompt.id) ? .blue : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
                
                Text(prompt.title)
                    .font(.system(size: 15 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let folder = prompt.folder, !folder.isEmpty {
                    let color = currentCategoryColor
                    Text(folder)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                recommendedBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)
            
            // Description (Moved above image)
            if let desc = prompt.promptDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
            
            // Image Preview (Carrusel con swipe de trackpad)
            if hasPreviewImage {
                let allPaths = prompt.showcaseImagePaths
                let allThumbs = prompt.showcaseThumbnails
                let imageCount = max(allPaths.count, allThumbs.isEmpty ? (previewThumbnailData != nil ? 1 : 0) : allThumbs.count)
                
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .bottomTrailing) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.03))
                            .frame(height: 180)
                            .overlay(
                                Group {
                                    if currentImageIndex < allThumbs.count {
                                        DownsampledImageView(
                                            imageData: allThumbs[currentImageIndex],
                                            cacheKey: "\(prompt.id.uuidString):grid:thumb:\(currentImageIndex)",
                                            maxPixelSize: 360,
                                            contentMode: isAspectFit ? .fit : .fill
                                        )
                                    } else if currentImageIndex < allPaths.count {
                                        let path = allPaths[currentImageIndex]
                                        let url = imageStore.url(forRelativePath: path)
                                        DownsampledImageURLView(
                                            imageURL: url,
                                            cacheKey: "\(prompt.id.uuidString):grid:\(currentImageIndex):360:\(path)",
                                            maxPixelSize: 360,
                                            contentMode: isAspectFit ? .fit : .fill
                                        )
                                    } else if let thumbnailData = previewThumbnailData {
                                        DownsampledImageView(
                                            imageData: thumbnailData,
                                            cacheKey: "\(prompt.id.uuidString):grid:thumb:0",
                                            maxPixelSize: 360,
                                            contentMode: isAspectFit ? .fit : .fill
                                        )
                                    } else if let firstPath = previewRelativePath {
                                        let url = imageStore.url(forRelativePath: firstPath)
                                        DownsampledImageURLView(
                                            imageURL: url,
                                            cacheKey: "\(prompt.id.uuidString):grid:0:360:\(firstPath)",
                                            maxPixelSize: 360,
                                            contentMode: isAspectFit ? .fit : .fill
                                        )
                                    }
                                }
                                .id(currentImageIndex)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(x: 18)).animation(.easeOut(duration: 0.22)),
                                    removal: .opacity.combined(with: .offset(x: -18)).animation(.easeIn(duration: 0.18))
                                ))
                            )
                            .clipped()
                            // Captura scroll horizontal del trackpad para cambiar imagen
                            .overlay(
                                imageCount > 1 ?
                                    AnyView(
                                        HorizontalScrollWheelCapture { deltaX in
                                            handleCarouselScroll(deltaX: deltaX, imageCount: imageCount)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    )
                                : AnyView(EmptyView())
                            )
                        
                        // Fit/Fill Control
                        if effectiveHover {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    isAspectFit.toggle()
                                }
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: isAspectFit ? "arrow.up.left.and.arrow.down.right" : "arrow.down.forward.and.arrow.up.backward")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.85).combined(with: .opacity).animation(.spring(response: 0.3)),
                                removal: .opacity.animation(.easeOut(duration: 0.2))
                            ))
                        }
                    }
                    
                    // Indicadores de puntos (solo si hay más de 1 imagen)
                    if imageCount > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<imageCount, id: \.self) { i in
                                Circle()
                                    .fill(i == currentImageIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .padding(.bottom, 8)
                    }
                }
            }
            
            // Content Snippet
            VStack(alignment: .leading, spacing: 6) {
                snippetView
                    .lineLimit(isPerformanceMode ? (hasPreviewImage ? 1 : 2) : (hasPreviewImage ? 2 : 4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Spacer(minLength: 0)
            
            // Footer: Indicators and Actions
            HStack(spacing: 8) {
                if prompt.useCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 8))
                        Text("\(prompt.useCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
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
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
                
                if !prompt.versionHistory.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8))
                        Text("\(prompt.versionHistory.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.purple.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                

            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.01))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.03)), alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isRecommended ? themeColor.opacity(isGlowAnimating ? 0.15 : 0.05) : (isSelected || effectiveHover ? themeColor.opacity(0.06) : Color.clear))
                        .blur(radius: isRecommended ? (isGlowAnimating ? 15 : 8) : (preferences.isHaloEffectEnabled && effectiveHover ? 12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isRecommended ? themeColor.opacity(isGlowAnimating ? 0.8 : 0.3) : cardBorderColor, lineWidth: isRecommended ? 1.5 : (isSelected ? 1.5 : 1))
                )
        )
        .shadow(color: isRecommended ? themeColor.opacity(isGlowAnimating ? 0.4 : 0.1) : .black.opacity(effectiveHover ? 0.06 : (isPerformanceMode ? 0.01 : 0.02)), radius: isRecommended ? 8 : (isPerformanceMode ? 4 : 8), y: isRecommended ? 0 : (isPerformanceMode ? 2 : 4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .clipped()
        .contentShape(Rectangle())
        .onAppear {
            refreshHighlightedContentCacheIfNeeded()
            if isRecommended {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    isGlowAnimating = true
                }
            }
        }
        .task(id: highlightedContentRefreshToken) {
            refreshHighlightedContentCacheIfNeeded()
        }
        .onTapGesture {
            let isCmdPressed = NSEvent.modifierFlags.contains(.command)
            
            if batchService.isSelectionModeActive || isCmdPressed {
                if !batchService.isSelectionModeActive {
                    withAnimation(.spring(response: 0.3)) {
                        batchService.isSelectionModeActive = true
                    }
                }
                batchService.toggleSelection(for: prompt.id)
                HapticService.shared.playLight()
            } else {
                onTap()
            }
        }
        .onHover { hovering in
            if hoverEffectsEnabled {
                isLocallyHovered = hovering
            }
            onHover(hovering)
        }
        .task {
            if prompt.showcaseImageCount > 0,
               previewThumbnailData == nil,
               prompt.showcaseImagePaths.isEmpty,
               fallbackShowcasePath == nil {
                fallbackShowcasePath = await promptService.fetchShowcaseImagePaths(byId: prompt.id).first
            }
        }
        .onDrag {
            let provider = NSItemProvider()
            let selectedIds = batchService.selectedPromptIds
            let draggedIds: [UUID]
            
            if batchService.isSelectionModeActive,
               selectedIds.contains(prompt.id),
               selectedIds.count > 1 {
                draggedIds = selectedIds.sorted { $0.uuidString < $1.uuidString }
            } else {
                draggedIds = [prompt.id]
            }

            // Payload para Drag & Drop coherente con PromptCard y Sidebar
            struct PromtierDragPayload: Codable {
                let kind: String
                let ids: [String]
            }
            
            let payload = PromtierDragPayload(kind: "promtier.prompt.ids", ids: draggedIds.map { $0.uuidString })
            if let data = try? JSONEncoder().encode(payload) {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.json.identifier, visibility: .all) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            
            // Para aplicaciones externas
            provider.registerObject(prompt.content as NSString, visibility: .all)
            
            return provider
        }
    }
    
    private var cardBackgroundColor: Color {
        let isBatchSelected = batchService.selectedPromptIds.contains(prompt.id)
        if isBatchSelected { return Color.blue.opacity(0.12) }
        else if isSelected { return Color.blue.opacity(0.05) }
        else if effectiveHover { return Color.primary.opacity(0.04) }
        else { return Color.primary.opacity(0.02) }
    }
    
    private var cardBorderColor: Color {
        if isSelected { return themeColor.opacity(0.5) }
        else if effectiveHover { return themeColor.opacity(0.2) }
        else { return Color.primary.opacity(0.06) }
    }
    
    private func handleCarouselScroll(deltaX: CGFloat, imageCount: Int) {
        carouselScrollAccumulator += deltaX
        let threshold: CGFloat = 28
        if carouselScrollAccumulator > threshold {
            carouselScrollAccumulator = 0
            let newIndex = max(0, currentImageIndex - 1)
            guard newIndex != currentImageIndex else { return }
            carouselDirection = -1
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                currentImageIndex = newIndex
            }
            HapticService.shared.playLight()
        } else if carouselScrollAccumulator < -threshold {
            carouselScrollAccumulator = 0
            let newIndex = min(imageCount - 1, currentImageIndex + 1)
            guard newIndex != currentImageIndex else { return }
            carouselDirection = 1
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                currentImageIndex = newIndex
            }
            HapticService.shared.playLight()
        }
    }
}

// MARK: - HorizontalScrollWheelCapture (trackpad swipe horizontal)
private struct HorizontalScrollWheelCapture: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> HorizontalScrollCaptureNSView {
        let view = HorizontalScrollCaptureNSView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: HorizontalScrollCaptureNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class HorizontalScrollCaptureNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    
    override var acceptsFirstResponder: Bool { false }
    
    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        let dx = abs(event.scrollingDeltaX)
        let dy = abs(event.scrollingDeltaY)
        
        // Solo capturar si el gesto es predominantemente horizontal (dx > 2*dy)
        // En todos los demás casos se pasa al nextResponder (el ScrollView de la galería)
        let isHorizontalDominant = dx > dy * 2 && (event.phase != [] || event.momentumPhase != [])
        if isHorizontalDominant {
            onScroll?(event.scrollingDeltaX)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}
