//
//  PromptCard+Presentation.swift
//  Promtier
//
//  Responsabilidad: Computed properties de presentación pura de PromptCard.
//  Ninguno de estos helpers toca red, disco ni servicios externos.
//

import SwiftUI

extension PromptCard {

    // MARK: - Dynamic Colors

    var cardBackgroundColor: Color {
        let isBatchSelected = batchService.selectedPromptIds.contains(prompt.id)
        if isBatchSelected  { return Color.blue.opacity(0.12) }
        if isSelected       { return Color.blue.opacity(0.05) }
        if effectiveHover   { return Color.primary.opacity(0.04) }
        return Color.primary.opacity(0.02)
    }

    var cardBorderColor: Color {
        if isSelected     { return themeColor.opacity(0.5) }
        if effectiveHover { return themeColor.opacity(0.2) }
        return Color.primary.opacity(0.06)
    }

    // MARK: - Theme

    var themeColor: Color {
        precomputedCategoryColor
    }

    // MARK: - Hover

    var hoverEffectsEnabled: Bool {
        !isPerformanceMode
    }

    var effectiveHover: Bool {
        isLocallyHovered || isHovered
    }

    // MARK: - Metadata

    var variableCount: Int {
        PromptCardTextCache.shared.variableCount(for: prompt)
    }

    var variableCountText: String {
        "\(variableCount) \(variableCount == 1 ? "variable" : "variables")"
    }

    var shortcutDisplay: String? {
        return ShortcutFormatter.format(shortcutString: prompt.customShortcut)
    }

    // MARK: - Recommendation

    var isRecommended: Bool {
        guard let bundleID = promptService.activeAppBundleID else { return false }
        return prompt.targetAppBundleIDs.contains(bundleID)
    }

    var currentCategoryColor: Color {
        guard let folderName = prompt.folder, !folderName.isEmpty else { return precomputedCategoryColor }
        if let folder = promptService.folders.first(where: { $0.name == folderName }) {
            return Color(hex: folder.displayColor)
        }
        return precomputedCategoryColor
    }

    // MARK: - Text Content Helpers

    var snippetView: some View {
        Group {
            if isPerformanceMode {
                Text(plainSnippetCache.isEmpty ? prompt.content : plainSnippetCache)
                    .font(.system(size: 12 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                Text(highlightedContentCache)
                    .font(.system(size: 12 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    // MARK: - Content Cache Key

    var highlightedContentRefreshToken: String {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        return "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):\(Int(preferences.fontSize.scale * 100)):" +
            "\(interfaceStyle == .dark ? "d" : "l"):" +
            "\(categoryNSColor.hexString):\(isPerformanceMode ? "p" : "n")"
    }

    // MARK: - Cache Refresh

    func refreshHighlightedContentCacheIfNeeded() {
        let interfaceStyle: PromptPreviewInterfaceStyle = colorScheme == .dark ? .dark : .light
        let categoryNSColor = NSColor(currentCategoryColor)
        let maxCharacters = isPerformanceMode ? 280 : 500
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
}
