import AppKit
import Foundation

enum PromptPreviewInterfaceStyle: String, Sendable {
    case light
    case dark
}

struct PromptPreviewThemeColor: Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        red = resolved.redComponent
        green = resolved.greenComponent
        blue = resolved.blueComponent
        alpha = resolved.alphaComponent
    }
}

final class PromptPreviewTextCache: @unchecked Sendable {
    nonisolated static let shared = PromptPreviewTextCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSAttributedString>()

    private init() {
        cache.countLimit = 256
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    nonisolated func cacheKey(promptId: UUID, modifiedAt: Date, scale: CGFloat, interfaceStyle: PromptPreviewInterfaceStyle) -> String {
        "\(promptId.uuidString):\(Int(scale * 100)):\(modifiedAt.timeIntervalSince1970):\(interfaceStyle.rawValue)"
    }

    nonisolated func cachedAttributedString(forKey key: String) -> NSAttributedString? {
        cache.object(forKey: key as NSString)
    }

    nonisolated func highlightedString(
        for prompt: Prompt,
        themeColor: PromptPreviewThemeColor,
        scale: CGFloat,
        interfaceStyle: PromptPreviewInterfaceStyle
    ) -> NSAttributedString {
        let key = cacheKey(promptId: prompt.id, modifiedAt: prompt.modifiedAt, scale: scale, interfaceStyle: interfaceStyle)
        if let cached = cachedAttributedString(forKey: key) {
            return cached
        }

        let text = prompt.content
        let highlighted = Self.buildHighlightedString(
            text: text,
            themeColor: themeColor,
            scale: scale,
            interfaceStyle: interfaceStyle
        )

        let cost = max(1, min(text.utf16.count * 4, 512_000))
        cache.setObject(highlighted, forKey: key as NSString, cost: cost)
        return highlighted
    }

    nonisolated private static func buildHighlightedString(
        text: String,
        themeColor: PromptPreviewThemeColor,
        scale: CGFloat,
        interfaceStyle: PromptPreviewInterfaceStyle
    ) -> NSAttributedString {
        let accentColor = NSColor(
            calibratedRed: themeColor.red, green: themeColor.green, blue: themeColor.blue, alpha: themeColor.alpha
        )
        let bodyColor: NSColor = interfaceStyle == .dark
            ? NSColor.white.withAlphaComponent(0.9)
            : NSColor.black.withAlphaComponent(0.88)

        let baseFont = NSFont.systemFont(ofSize: 16 * scale, weight: .regular)
        
        // Usar el convertidor de Markdown para procesar negritas, cursivas, etc.
        let attributed = MarkdownRTFConverter.parseMarkdown(text, baseFont: baseFont, textColor: bodyColor)

        let nsText = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for match in PromtierRegex.bracket.matches(in: attributed.string, options: [], range: fullRange) {
            attributed.addAttribute(.foregroundColor, value: accentColor.withAlphaComponent(0.8), range: match.range)
        }

        let variableFont = NSFont.systemFont(ofSize: 16 * scale, weight: .bold)
        let variableColor = NSColor.systemBlue
        for match in PromtierRegex.variable.matches(in: attributed.string, options: [], range: fullRange).reversed() {
            attributed.addAttributes([
                .foregroundColor: variableColor,
                .font: variableFont
            ], range: match.range)
        }

        return attributed
    }
}
