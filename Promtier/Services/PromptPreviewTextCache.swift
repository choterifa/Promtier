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

    nonisolated private static let bracketRegex = try? NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
    nonisolated private static let variableRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])

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
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        let accentColor = NSColor(
            calibratedRed: themeColor.red,
            green: themeColor.green,
            blue: themeColor.blue,
            alpha: themeColor.alpha
        )
        let bodyColor: NSColor = interfaceStyle == .dark
            ? NSColor.white.withAlphaComponent(0.9)
            : NSColor.black.withAlphaComponent(0.88)

        let baseFont = NSFont.systemFont(ofSize: 16 * scale, weight: .regular)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: bodyColor,
                .paragraphStyle: paragraph
            ]
        )

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        if let bracketRegex = bracketRegex {
            for match in bracketRegex.matches(in: text, options: [], range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: accentColor.withAlphaComponent(0.8), range: match.range)
            }
        }

        if let variableRegex = variableRegex {
            let variableFont = NSFont.systemFont(ofSize: 16 * scale, weight: .bold)
            let variableColor = NSColor.systemBlue
            for match in variableRegex.matches(in: text, options: [], range: fullRange).reversed() {
                attributed.addAttributes([
                    .foregroundColor: variableColor,
                    .font: variableFont,
                    .backgroundColor: variableColor.withAlphaComponent(0.08)
                ], range: match.range)
            }
        }

        return attributed
    }
}
