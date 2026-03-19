//
//  Color+Extensions.swift
//  Promtier
//
//  EXTENSIONES: Extensiones para Color y otros tipos
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit

// MARK: - Color Extensions

extension Color {
    /// Convierte Color a string hexadecimal
    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
    
    /// Crea Color desde string hexadecimal
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - AppAppearance Enum

enum AppAppearance: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Automático"
        }
    }
}

// MARK: - FontSize Enum

enum FontSize: String, CaseIterable {
    case xSmall = "xSmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case xLarge = "xLarge"
    
    var displayName: String {
        switch self {
        case .xSmall: return "Muy Pequeña"
        case .small: return "Pequeña"
        case .medium: return "Mediana"
        case .large: return "Grande"
        case .xLarge: return "Muy Grande"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .xSmall: return 0.75
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.2
        case .xLarge: return 1.4
        }
    }
    
    func bigger() -> FontSize {
        switch self {
        case .xSmall: return .small
        case .small: return .medium
        case .medium: return .large
        case .large: return .xLarge
        case .xLarge: return .xLarge
        }
    }
    
    func smaller() -> FontSize {
        switch self {
        case .xSmall: return .xSmall
        case .small: return .xSmall
        case .medium: return .small
        case .large: return .medium
        case .xLarge: return .large
        }
    }
}

// MARK: - AppLanguage Enum

enum AppLanguage: String, CaseIterable {
    case spanish = "es"
    case english = "en"
    
    var displayName: LocalizedStringKey {
        switch self {
        case .spanish: return "spanish"
        case .english: return "english"
        }
    }
    
    var locale: Locale {
        switch self {
        case .spanish: return Locale(identifier: "es")
        case .english: return Locale(identifier: "en")
        }
    }
}

// MARK: - Predefined Categories

enum PredefinedCategory: String, CaseIterable {
    case code = "Code"
    case writing = "Writing"
    case imageGen = "Image Generation"
    case marketing = "Marketing"
    case productivity = "Productivity"
    case automation = "Automation"
    
    var displayName: String {
        let language = PreferencesManager.shared.language
        switch self {
        case .code: return "cat_code".localized(for: language)
        case .writing: return "cat_writing".localized(for: language)
        case .imageGen: return "cat_image_gen".localized(for: language)
        case .marketing: return "cat_marketing".localized(for: language)
        case .productivity: return "cat_productivity".localized(for: language)
        case .automation: return "cat_automation".localized(for: language)
        }
    }
    
    var color: Color {
        switch self {
        case .code: return Color.green
        case .writing: return Color.blue
        case .imageGen: return Color.purple
        case .marketing: return Color.orange
        case .productivity: return Color.pink
        case .automation: return Color.yellow
        }
    }
    
    var hexColor: String {
        switch self {
        case .code: return "#34C759"
        case .writing: return "#007AFF"
        case .imageGen: return "#AF52DE"
        case .marketing: return "#FF9500"
        case .productivity: return "#FF2D92"
        case .automation: return "#FFCC00"
        }
    }
    
    var icon: String {
        switch self {
        case .code: return "terminal.fill"
        case .writing: return "square.and.pencil"
        case .imageGen: return "sparkles"
        case .marketing: return "megaphone.fill"
        case .productivity: return "list.bullet.rectangle.portrait.fill"
        case .automation: return "bolt.fill"
        }
    }
    
    static func fromString(_ category: String?) -> PredefinedCategory? {
        guard let category = category else { return nil }
        return Self.allCases.first { $0.displayName == category }
    }
}

extension NSColor {
    var hexString: String {
        guard let rgbColor = self.usingColorSpace(.sRGB) else {
            return "FFFFFF"
        }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
