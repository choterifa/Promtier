import AppKit
import Foundation

final class PromptCardTextCache: @unchecked Sendable {
    nonisolated static let shared = PromptCardTextCache()

    nonisolated private static let bracketRegex = try? NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
    nonisolated private static let variableRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])

    nonisolated(unsafe) private let cache = NSCache<NSString, NSAttributedString>()
    nonisolated(unsafe) private let variableCountCache = NSCache<NSString, NSNumber>()

    private init() {
        cache.countLimit = 768
        cache.totalCostLimit = 20 * 1024 * 1024
        variableCountCache.countLimit = 4096
    }

    nonisolated func variableCount(for prompt: Prompt) -> Int {
        let key = "\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970):var-count"
        if let cached = variableCountCache.object(forKey: key as NSString) {
            return cached.intValue
        }

        let content = prompt.content
        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        var seen = Set<String>()
        var count = 0

        if let variableRegex = Self.variableRegex {
            variableRegex.enumerateMatches(in: content, options: [], range: fullRange) { match, _, _ in
                guard let captureRange = match?.range(at: 1),
                      let range = Range(captureRange, in: content) else { return }

                let variableName = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !variableName.isEmpty, !seen.contains(variableName) else { return }
                seen.insert(variableName)
                count += 1
            }
        }

        variableCountCache.setObject(NSNumber(value: count), forKey: key as NSString)
        return count
    }

    nonisolated func highlightedSnippet(
        for prompt: Prompt,
        maxCharacters: Int,
        categoryColor: NSColor,
        scale: CGFloat,
        interfaceStyle: PromptPreviewInterfaceStyle
    ) -> NSAttributedString {
        let key = cacheKey(
            promptId: prompt.id,
            modifiedAt: prompt.modifiedAt,
            maxCharacters: maxCharacters,
            scale: scale,
            interfaceStyle: interfaceStyle,
            categoryColor: categoryColor
        )
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let text = String(prompt.content.prefix(maxCharacters))
        let highlighted = Self.buildHighlightedSnippet(
            text: text,
            categoryColor: categoryColor,
            scale: scale,
            interfaceStyle: interfaceStyle
        )

        let cost = max(1, min(text.utf16.count * 4, 256_000))
        cache.setObject(highlighted, forKey: key as NSString, cost: cost)
        return highlighted
    }

    nonisolated private func cacheKey(
        promptId: UUID,
        modifiedAt: Date,
        maxCharacters: Int,
        scale: CGFloat,
        interfaceStyle: PromptPreviewInterfaceStyle,
        categoryColor: NSColor
    ) -> String {
        let resolved = (categoryColor.usingColorSpace(.deviceRGB) ?? categoryColor)
        let r = Int((resolved.redComponent * 255.0).rounded())
        let g = Int((resolved.greenComponent * 255.0).rounded())
        let b = Int((resolved.blueComponent * 255.0).rounded())
        let a = Int((resolved.alphaComponent * 255.0).rounded())
        return "\(promptId.uuidString):\(modifiedAt.timeIntervalSince1970):\(maxCharacters):\(Int(scale * 100)):\(interfaceStyle.rawValue):\(r)-\(g)-\(b)-\(a)"
    }

    nonisolated private static func buildHighlightedSnippet(
        text: String,
        categoryColor: NSColor,
        scale: CGFloat,
        interfaceStyle: PromptPreviewInterfaceStyle
    ) -> NSAttributedString {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // Match existing cards: keep font relatively small and let SwiftUI apply the base foreground color.
        let baseFont = NSFont.systemFont(ofSize: 13 * scale, weight: .regular)
        let attributed = NSMutableAttributedString(string: text, attributes: [.font: baseFont])

        let accent = (categoryColor.usingColorSpace(.deviceRGB) ?? categoryColor).withAlphaComponent(0.8)
        if let bracketRegex = bracketRegex {
            for match in bracketRegex.matches(in: text, options: [], range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: accent, range: match.range)
            }
        }

        if let variableRegex = variableRegex {
            let variableFont = NSFont.systemFont(ofSize: 13 * scale, weight: .bold)
            let variableColor = NSColor.systemBlue
            let variableBg = variableColor.withAlphaComponent(0.08)
            for match in variableRegex.matches(in: text, options: [], range: fullRange).reversed() {
                attributed.addAttributes([
                    .foregroundColor: variableColor,
                    .font: variableFont,
                    .backgroundColor: variableBg
                ], range: match.range)
            }
        }

        return attributed
    }
}
