//
//  PromptCard.swift
//  Promtier
//
//  VISTA: Card moderna para mostrar prompts en la lista
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

private struct PromtierDragPayload: Codable {
    let kind: String
    let ids: [String]
}

struct PromptCard: View {
    let prompt: Prompt
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
    
    // EXTENSIÓN: Contador de variables
    private var variableCount: Int {
        prompt.extractTemplateVariables().count
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
    
    private func getFolderColor(for folderName: String) -> Color {
        if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
            return Color(hex: customFolder.displayColor)
        }
        return PredefinedCategory.fromString(folderName)?.color ?? .blue
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
            
            // Icono de categoría o personalizado grande restaurado
            if let iconName = prompt.icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill((prompt.folder != nil ? getFolderColor(for: prompt.folder!) : .blue).opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(prompt.folder != nil ? getFolderColor(for: prompt.folder!) : .blue)
                }
            } else if let folder = prompt.folder {
                let color = getFolderColor(for: folder)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
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
                HStack(alignment: .center, spacing: 8) {
                    Text(prompt.title)
                        .font(.system(size: 15 * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)
                    
                    if let folder = prompt.folder, !folder.isEmpty {
                        let color = getFolderColor(for: folder)
                        Text(folder)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if let activeApp = promptService.activeAppBundleID, prompt.targetAppBundleIDs.contains(activeApp) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8, weight: .bold))
                            Text("recommended".localized(for: preferences.language))
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                if let desc = prompt.promptDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.65))
                        .lineLimit(1)
                }
                
                Text(highlightedContent)
                    .font(.system(size: 13 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(prompt.promptDescription != nil ? 2 : 3)
            }
            
            Spacer()
            
            // Indicadores de estado
            HStack(spacing: 8) {
                // 1. Indicador de Prompt Negativo / Alternativo (PUNTOS)
                let hasNegative = (prompt.negativePrompt?.isEmpty == false)
                let hasAlternativeField = (prompt.alternativePrompt?.isEmpty == false)
                if hasNegative || hasAlternativeField {
                    HStack(spacing: 4) {
                        if hasNegative {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                        }
                        if hasAlternativeField {
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.trailing, 4)
                }

                // 2. Indicador de Alternativas (ARRAY) - Nuevo
                if !prompt.alternatives.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "square.3.layers.3d.down.right")
                            .font(.system(size: 8))
                        Text("\(prompt.alternatives.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.teal.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.teal.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                // 3. Indicador de Variables (Cubo)
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

                // 4. Indicador de Imagen
                if prompt.showcaseImageCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 8))
                        Text("\(prompt.showcaseImageCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.cyan.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(Capsule())
                }

                // 5. Veces copiado (A LA DERECHA DE LOS ANTERIORES)
                if prompt.useCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc.fill")
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
                
                // 6. Indicador de Versiones (Premium)
                if !prompt.versionHistory.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8))
                        Text("\(prompt.versionHistory.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.purple.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }

                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                        .shadow(color: .yellow.opacity(0.3), radius: 2)
                }
                
                // Indicador de Atajo Personalizado (Movido al final como se solicitó)
                if let display = shortcutDisplay {
                    Text(display)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                        )
                }
                
                if let onCopy = onCopy {
                    Button(action: {
                        onCopy()
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary.opacity(isHovered || isSelected ? 0.9 : 0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(isHovered || isSelected ? 0.05 : 0))
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("copy".localized(for: preferences.language))
                    .contextMenu {
                        Button(action: { onCopy() }) {
                            Label("copy".localized(for: preferences.language), systemImage: "doc.on.doc")
                        }
                        if let onCopyPack = onCopyPack {
                            Button(action: { onCopyPack() }) {
                                Label("copy_pack".localized(for: preferences.language), systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary.opacity(0.2))
                    .opacity(isHovered || isSelected ? 1 : 0)
                    .frame(width: 10) // Espacio fijo reservado
            }
        }

        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
        // Eliminado scaleEffect para mayor estabilidad visual
        .shadow(color: .black.opacity(isHovered ? 0.05 : 0.0), radius: 8, y: 4)
        .contentShape(Rectangle())
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
            
            // 2. Contenido para apps externas (Texto plano)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                completion(prompt.content.data(using: .utf8), nil)
                return nil
            }
            
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
