import AppKit
import Foundation

extension NSAttributedString.Key {
    static let promtierInlineCode = NSAttributedString.Key("com.promtier.inlineCode")
}

public enum PromtierRegex {
    public static let bold = try! NSRegularExpression(pattern: "\\*\\*([^\\*]+)\\*\\*|__([^_]+)__")
    public static let italic = try! NSRegularExpression(pattern: "(?<![a-zA-Z0-9_\\*])\\*(?=\\S)([^\\n]*?)(?<=\\S)\\*(?![a-zA-Z0-9_\\*])|(?<![a-zA-Z0-9_])_(?=\\S)([^\\n]*?)(?<=\\S)_(?![a-zA-Z0-9_])")
    public static let strikethrough = try! NSRegularExpression(pattern: "~~([^~]+)~~")
    public static let inlineCode = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
    public static let bulletList = try! NSRegularExpression(pattern: "^\\s*([-*+•])\\s+", options: [.anchorsMatchLines])
    public static let numberedList = try! NSRegularExpression(pattern: "^\\s*(\\d+\\.)\\s+", options: [.anchorsMatchLines])
    public static let variable = try! NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])
    public static let chain = try! NSRegularExpression(pattern: "\\[\\[@Prompt:([^\\]]+)\\]\\]", options: [])
    public static let bracket = try! NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
}

final class MarkdownRTFConverter {

    static func parseMarkdown(_ markdown: String, baseFont: NSFont, textColor: NSColor) -> NSMutableAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: defaultParagraphStyle()
        ]

        let attributed = NSMutableAttributedString(string: markdown, attributes: baseAttributes)

        applyInlineMarkdown(regex: PromtierRegex.inlineCode, markerLength: 1, to: attributed) { innerRange in
            let font = NSFont.monospacedSystemFont(ofSize: max(11, baseFont.pointSize - 1), weight: .regular)
            
            let dynamicForeground = NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(calibratedRed: 0.88, green: 0.78, blue: 0.96, alpha: 1.0)
                } else {
                    return NSColor(calibratedRed: 0.46, green: 0.24, blue: 0.58, alpha: 1.0)
                }
            }

            attributed.addAttributes([
                .font: font,
                .foregroundColor: dynamicForeground,
                .promtierInlineCode: true
            ], range: innerRange)
        }

        applyInlineMarkdown(regex: PromtierRegex.bold, markerLength: 2, to: attributed) { innerRange in
            let currentFont = (attributed.attribute(.font, at: innerRange.location, effectiveRange: nil) as? NSFont) ?? baseFont
            attributed.addAttribute(.font, value: toggledFont(from: currentFont, add: .boldFontMask), range: innerRange)
        }

        applyInlineMarkdown(regex: PromtierRegex.italic, markerLength: 1, to: attributed) { innerRange in
            let currentFont = (attributed.attribute(.font, at: innerRange.location, effectiveRange: nil) as? NSFont) ?? baseFont
            attributed.addAttribute(.font, value: toggledFont(from: currentFont, add: .italicFontMask), range: innerRange)
        }

        applyInlineMarkdown(regex: PromtierRegex.strikethrough, markerLength: 2, to: attributed) { innerRange in
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: innerRange)
        }

        applyParagraphStyles(to: attributed, baseFont: baseFont)
        return attributed
    }

    static func generateMarkdown(from attributed: NSAttributedString) -> String {
        var result = ""
        let nsString = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: attributed.length)

        attributed.enumerateAttributes(in: fullRange) { attrs, range, _ in
            let chunk = nsString.substring(with: range)
            result += markdownChunk(for: chunk, attributes: attrs)
        }

        return result
    }

    static func applyParagraphStyles(to attributed: NSMutableAttributedString, baseFont: NSFont) {
        let text = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        let paragraph = defaultParagraphStyle()

        attributed.enumerateAttribute(.paragraphStyle, in: fullRange) { _, range, _ in
            attributed.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }

        let bulletMatches = PromtierRegex.bulletList.matches(in: attributed.string, range: fullRange)
        let numberedMatches = PromtierRegex.numberedList.matches(in: attributed.string, range: fullRange)

        for match in bulletMatches + numberedMatches {
            let lineRange = text.lineRange(for: match.range)
            let indent = NSMutableParagraphStyle()
            indent.lineSpacing = 5
            indent.paragraphSpacing = 10
            indent.firstLineHeadIndent = 0
            indent.headIndent = 22
            indent.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
            attributed.addAttribute(.paragraphStyle, value: indent, range: lineRange)
        }
    }

    static func toggledFont(from font: NSFont, add trait: NSFontTraitMask) -> NSFont {
        let hasTrait = font.fontDescriptor.symbolicTraits.contains(symbolicTrait(for: trait))
        if hasTrait {
            return NSFontManager.shared.convert(font, toNotHaveTrait: trait)
        }
        return NSFontManager.shared.convert(font, toHaveTrait: trait)
    }

    private static func applyInlineMarkdown(
        regex: NSRegularExpression,
        markerLength: Int,
        to attributed: NSMutableAttributedString,
        body: (NSRange) -> Void
    ) {
        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.length))
        for match in matches.reversed() {
            guard match.range.length > markerLength * 2 else { continue }
            let innerRange = NSRange(
                location: match.range.location + markerLength,
                length: match.range.length - (markerLength * 2)
            )

            body(innerRange)

            attributed.deleteCharacters(in: NSRange(location: innerRange.location + innerRange.length, length: markerLength))
            attributed.deleteCharacters(in: NSRange(location: match.range.location, length: markerLength))
        }
    }

    private static func markdownChunk(for text: String, attributes: [NSAttributedString.Key: Any]) -> String {
        guard !text.isEmpty else { return "" }

        let font = attributes[.font] as? NSFont
        let isCode = (attributes[.promtierInlineCode] as? Bool) == true || (font?.isFixedPitch ?? false)
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        let isBold = traits.contains(.bold)
        let isItalic = traits.contains(.italic)
        let isStrikethrough = (attributes[.strikethroughStyle] as? NSNumber)?.intValue ?? 0 > 0

        var prefix = ""
        var suffix = ""

        if isCode {
            prefix = "`"
            suffix = "`"
        } else {
            if isStrikethrough {
                prefix += "~~"
                suffix = "~~" + suffix
            }
            if isBold {
                prefix += "**"
                suffix = "**" + suffix
            }
            if isItalic {
                prefix += "*"
                suffix = "*" + suffix
            }
        }

        if !text.contains("\n") {
            return prefix + text + suffix
        }

        let parts = text.split(separator: "\n", omittingEmptySubsequences: false)
        return parts.enumerated().map { index, part in
            let wrapped = prefix + String(part) + suffix
            return index < parts.count - 1 ? wrapped + "\n" : wrapped
        }.joined()
    }

    static func defaultParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 10
        return paragraph
    }

    private static func symbolicTrait(for trait: NSFontTraitMask) -> NSFontDescriptor.SymbolicTraits {
        switch trait {
        case .boldFontMask:
            return .bold
        case .italicFontMask:
            return .italic
        default:
            return []
        }
    }
}
