//
//  PromptCard.swift
//  Promtier
//
//  VISTA: Card moderna para mostrar prompts en la lista
//  Created by Carlos on 15/03/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct PromtierDragPayload: Codable {
    let kind: String
    let ids: [String]
}

struct IndicatorBadge: View {
    let icon: String
    let count: Int
    let color: Color
    let help: String?
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(color.opacity(0.7))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .help(help ?? "")
    }
}

struct PromptCard: View {
    let prompt: Prompt
    let precomputedCategoryColor: Color
    let precomputedResolvedIcon: String
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: (() -> Void)?
    let onCopyPack: (() -> Void)?
    let onHover: (Bool) -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @State private var isTargetedForDrop = false
    @State private var isGlowAnimating = false
    @State private var isLocallyHovered = false
    @State private var highlightedContentCache: AttributedString = AttributedString("")
    @State private var highlightedContentCacheKey: String = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    private func refreshHighlightedContentCacheIfNeeded() {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        let key = "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):\(Int(preferences.fontSize.scale * 100)):" +
            "\(interfaceStyle == .dark ? "d" : "l"):" +
            "\(categoryNSColor.hexString)"

        guard highlightedContentCacheKey != key else { return }
        highlightedContentCacheKey = key

        let cached = PromptCardTextCache.shared.highlightedSnippet(
            for: prompt,
            maxCharacters: 500,
            categoryColor: categoryNSColor,
            scale: preferences.fontSize.scale,
            interfaceStyle: interfaceStyle
        )
        highlightedContentCache = AttributedString(cached)
    }

    private var highlightedContentRefreshToken: String {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        return "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):\(Int(preferences.fontSize.scale * 100)):" +
            "\(interfaceStyle == .dark ? "d" : "l"):" +
            "\(categoryNSColor.hexString)"
    }
    
    // EXTENSIÓN: Contador de variables
    private var variableCount: Int {
        PromptCardTextCache.shared.variableCount(for: prompt)
    }

    private var variableCountText: String {
        "\(variableCount)"
    }
    
    private var shortcutDisplay: String? {
        guard let shortcutStr = prompt.customShortcut else { return nil }
        let parts = shortcutStr.split(separator: ":")
        guard parts.count == 2,
              let kc = UInt32(parts[0]),
              let mods = UInt(parts[1]) else { return nil }
        
        var display = ""
        let flags = NSEvent.ModifierFlags(rawValue: mods)
        if flags.contains(.control) { display += "⌃" }
        if flags.contains(.option) { display += "⌥" }
        if flags.contains(.shift) { display += "⇧" }
        if flags.contains(.command) { display += "⌘" }
        
        if let char = keyMap[Int(kc)] {
            display += char
        } else {
            display += "?"
        }
        
        return display
    }
    
    private let keyMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        50: "`", 65: ".", 67: "*", 69: "+", 71: "Clear", 75: "/", 76: "Enter", 78: "-",
        81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    
    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : Color.blue
    }

    private var effectiveHover: Bool {
        isHovered || isLocallyHovered
    }
    
    private var isRecommended: Bool {
        guard let activeApp = promptService.activeAppBundleID else { return false }
        return prompt.targetAppBundleIDs.contains(activeApp)
    }
    
    private var currentCategoryColor: Color {
        precomputedCategoryColor
    }

    init(
        prompt: Prompt,
        precomputedCategoryColor: Color = .blue,
        precomputedResolvedIcon: String = "doc.text.fill",
        isSelected: Bool,
        isHovered: Bool,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onCopy: (() -> Void)?,
        onCopyPack: (() -> Void)?,
        onHover: @escaping (Bool) -> Void
    ) {
        self.prompt = prompt
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onCopy = onCopy
        self.onCopyPack = onCopyPack
        self.onHover = onHover

        self.precomputedCategoryColor = precomputedCategoryColor
        self.precomputedResolvedIcon = precomputedResolvedIcon
    }

    var body: some View {
        HStack(spacing: 16) {
            // Checkbox para selección en lote
            if batchService.isSelectionModeActive {
                Button(action: {
                    batchService.toggleSelection(for: prompt.id)
                    HapticService.shared.playLight()
                }) {
                    Image(systemName: batchService.selectedPromptIds.contains(prompt.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(batchService.selectedPromptIds.contains(prompt.id) ? .blue : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // Icono de categoría/Prompt
            let resolvedIcon = precomputedResolvedIcon
            
            let color = currentCategoryColor
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: resolvedIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Contenido de Texto
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(prompt.title)
                        .font(.system(size: 14 * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(2)
                    
                    if let folder = prompt.folder, !folder.isEmpty {
                        let color = currentCategoryColor
                        Text(folder)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if isRecommended {
                        HStack(spacing: 3) {
                            if let activeApp = promptService.activeAppBundleID {
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
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                
                if let desc = prompt.promptDescription, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(desc)
                            .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.65))
                            .lineLimit(desc.count < 55 ? 1 : 2)
                        
                        if desc.count < 55 {
                            Text(highlightedContentCache)
                                .font(.system(size: 13 * preferences.fontSize.scale))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text(highlightedContentCache)
                        .font(.system(size: 13 * preferences.fontSize.scale))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            // Indicadores
            HStack(spacing: 8) {
                let hasNegative = !(prompt.negativePrompt?.isEmpty ?? true)
                let hasAlternativeField = !(prompt.alternativePrompt?.isEmpty ?? true)
                
                if hasNegative || hasAlternativeField {
                    HStack(spacing: 4) {
                        if hasNegative {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                        }
                        if hasAlternativeField {
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 6, height: 6)
                        }
                    }
                }

                if !prompt.alternatives.isEmpty {
                    IndicatorBadge(icon: "square.3.layers.3d.down.right", count: prompt.alternatives.count, color: .teal, help: "tooltip_alternatives".localized(for: preferences.language))
                }
                
                if variableCount > 0 {
                    IndicatorBadge(icon: "cube.transparent.fill", count: variableCount, color: .blue, help: "tooltip_variables".localized(for: preferences.language))
                }

                if prompt.showcaseImageCount > 0 {
                    IndicatorBadge(icon: "photo.fill", count: prompt.showcaseImageCount, color: .cyan, help: "tooltip_images".localized(for: preferences.language))
                }

                if prompt.parentID != nil {
                    Image(systemName: "arrow.branch")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                        .help("tooltip_branch".localized(for: preferences.language))
                }
                
                if !prompt.versionHistory.isEmpty {
                    IndicatorBadge(icon: "clock.arrow.circlepath", count: prompt.versionHistory.count, color: .purple, help: "tooltip_versions".localized(for: preferences.language))
                }

                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
                
                if let display = shortcutDisplay {
                    Text(display)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(4)
                }
                

                
                if prompt.useCount > 0 {
                    IndicatorBadge(icon: "doc.on.doc.fill", count: prompt.useCount, color: .secondary, help: "tooltip_use_count".localized(for: preferences.language))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary.opacity(0.15))
                    .opacity(effectiveHover || isSelected ? 1 : 0)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
        .frame(minHeight: 82)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isRecommended ? themeColor.opacity(isGlowAnimating ? 0.15 : 0.05) : (isSelected || effectiveHover ? themeColor.opacity(0.08) : Color.clear))
                        .blur(radius: isRecommended ? (isGlowAnimating ? 15 : 8) : (preferences.isHaloEffectEnabled && effectiveHover ? 12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isRecommended ? themeColor.opacity(isGlowAnimating ? 0.8 : 0.3) : cardBorderColor, lineWidth: isRecommended ? 1.5 : (isSelected ? 1.5 : 1))
                )
        )
        // Eliminado scaleEffect para mayor estabilidad visual
        .shadow(color: isRecommended ? themeColor.opacity(isGlowAnimating ? 0.4 : 0.1) : .black.opacity(effectiveHover ? 0.05 : 0.0), radius: isRecommended ? 8 : 8, y: isRecommended ? 0 : 4)
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
        // USAR BUTTON PARA RESPUESTA INSTANTÁNEA (Sin delay de doble clic)
        .onTapGesture {
            if batchService.isSelectionModeActive {
                batchService.toggleSelection(for: prompt.id)
                HapticService.shared.playLight()
            } else {
                onTap()
            }
        }
        // GESTO SIMULTÁNEO PARA EL DOBLE CLIC
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if !batchService.isSelectionModeActive {
                    onDoubleTap()
                }
            }
        )
        .onHover { hovering in
            isLocallyHovered = hovering
            onHover(hovering)
        }
        // SOPORTE DRAG AND DROP AVANZADO
        .onDrag {
            // MEJORA: No cerrar inmediatamente para permitir categorización interna (drag-to-sidebar).
            // Solo cerramos si detectamos que el arrastre sale de los límites de la ventana.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if let window = NSApp.keyWindow, 
                   window.className.contains("Popover"),
                   !NSMouseInRect(NSEvent.mouseLocation, window.frame, false) {
                    menuBarManager.closePopover()
                }
            }
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

            // Payload interno (SwiftUI Drop estable): JSON con ids (1..N)
            let payload = PromtierDragPayload(kind: "promtier.prompt.ids", ids: draggedIds.map { $0.uuidString })
            if let data = try? JSONEncoder().encode(payload) {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.json.identifier, visibility: .all) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            
            // 2. Contenido para apps externas (Texto plano - Máxima compatibilidad)
            provider.registerObject(prompt.content as NSString, visibility: .all)
            
            return provider
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargetedForDrop) { providers in
            // Lógica para añadir imágenes al prompt vía Drop
            handleImageDrop(providers: providers)
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue, lineWidth: isTargetedForDrop ? 2 : 0)
        )
    }
    
    private func handleImageDrop(providers: [NSItemProvider]) {
        Task(priority: .userInitiated) {
            let existing = await promptService.fetchShowcaseImages(byId: prompt.id)
            if existing.count >= 3 { return }

            var optimizedToAdd: [Data] = []
            let available = max(0, 3 - existing.count)

            for provider in providers {
                guard optimizedToAdd.count < available else { break }
                guard let raw = await loadImageData(from: provider) else { continue }
                let optimized = await Task.detached(priority: .userInitiated) {
                    ImageOptimizer.shared.optimize(imageData: raw)
                }.value
                guard let optimized else { continue }
                optimizedToAdd.append(optimized)
            }

            guard !optimizedToAdd.isEmpty else { return }
            let final = Array((existing + optimizedToAdd).prefix(3))
            let ok = await promptService.updateShowcaseImages(promptId: prompt.id, images: final)
            if ok {
                await MainActor.run {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        if provider.canLoadObject(ofClass: URL.self) {
            return await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else {
                        continuation.resume(returning: nil)
                        return
                    }
                    // Intentar leer archivo en background
                    let data = try? Data(contentsOf: url)
                    continuation.resume(returning: data)
                }
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { continuation in
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }

        return nil
    }
    
    // Colores dinámicos Premium
    private var cardBackgroundColor: Color {
        let isBatchSelected = batchService.selectedPromptIds.contains(prompt.id)
        
        if isBatchSelected {
            return Color.blue.opacity(0.12)
        } else if isSelected {
            return Color.blue.opacity(0.05)
        } else if effectiveHover {
            return Color.primary.opacity(0.04)
        } else {
            return Color.primary.opacity(0.02)
        }
    }
    
    private var cardBorderColor: Color {
        if isSelected {
            return themeColor.opacity(0.5)
        } else if effectiveHover {
            return themeColor.opacity(0.2)
        } else {
            return Color.primary.opacity(0.06)
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
            onCopy: nil,
            onCopyPack: nil,
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
            onCopy: nil,
            onCopyPack: nil,
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
            onCopy: nil,
            onCopyPack: nil,
            onHover: { _ in }
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
