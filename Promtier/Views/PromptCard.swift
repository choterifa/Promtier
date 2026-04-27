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
    let isPerformanceMode: Bool
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: (() -> Void)?
    let onCopyPack: (() -> Void)?
    let onHover: (Bool) -> Void            
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
    init(
        prompt: Prompt,
        precomputedCategoryColor: Color = .blue,
        precomputedResolvedIcon: String = "doc.text.fill",
        isPerformanceMode: Bool = false,
        isSelected: Bool,
        isHovered: Bool,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onCopy: (() -> Void)?,
        onCopyPack: (() -> Void)?,
        onHover: @escaping (Bool) -> Void
    ) {
        self.prompt = prompt
        self.isPerformanceMode = isPerformanceMode
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

    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService

    @State var isTargetedForDrop = false
    @State var isGlowAnimating = false
    @State var isLocallyHovered = false
    @State var highlightedContentCache: AttributedString = AttributedString("")
    @State var highlightedContentCacheKey: String = ""
    @State var plainSnippetCache: String = ""

    @Environment(\.colorScheme) var colorScheme

    private var mainCardContent: some View {
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
                            .lineLimit(isPerformanceMode ? 1 : (desc.count < 55 ? 1 : 2))
                        
                        if !isPerformanceMode && desc.count < 55 {
                            snippetView
                                .lineLimit(1)
                        }
                    }
                } else {
                    snippetView
                        .lineLimit(isPerformanceMode ? 2 : 3)
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
    }

    var body: some View {
        mainCardContent
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 14)
            .frame(minHeight: 82)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackgroundColor)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(glowFillColor)
                            .blur(radius: glowBlurRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(glowStrokeColor, lineWidth: glowStrokeLineWidth)
                    )
            )
            .shadow(color: cardShadowColor, radius: cardShadowRadius, y: cardShadowY)
        .contentShape(Rectangle())
        .onAppear {
            refreshHighlightedContentCacheIfNeeded()
            if isRecommended {
                startGlowAnimation()
            }
        }
        .onChange(of: isRecommended) { _, recommended in
            if recommended {
                startGlowAnimation()
            } else {
                stopGlowAnimation()
            }
        }
        .task(id: highlightedContentRefreshToken) {
            refreshHighlightedContentCacheIfNeeded()
        }
        // USAR BUTTON PARA RESPUESTA INSTANTÁNEA (Sin delay de doble clic)
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
        // GESTO SIMULTÁNEO PARA EL DOBLE CLIC
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if !batchService.isSelectionModeActive {
                    onDoubleTap()
                }
            }
        )
        .onHover { hovering in
            if hoverEffectsEnabled {
                isLocallyHovered = hovering
            }
            onHover(hovering)
        }
        // SOPORTE DRAG AND DROP AVANZADO
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

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            isGlowAnimating = true
        }
    }
    
    private func stopGlowAnimation() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isGlowAnimating = false
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
