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
    case iaModels = "IA/Modelos"
    case code = "Código"
    case creative = "Creativo"
    case work = "Trabajo"
    case personal = "Personal"
    case study = "Estudio"
    
    var displayName: String {
        let language = PreferencesManager.shared.language
        switch self {
        case .iaModels: return "cat_ai".localized(for: language)
        case .code: return "cat_code".localized(for: language)
        case .creative: return "cat_creative".localized(for: language)
        case .work: return "cat_work".localized(for: language)
        case .personal: return "cat_personal".localized(for: language)
        case .study: return "cat_study".localized(for: language)
        }
    }
    
    var color: Color {
        switch self {
        case .iaModels: return Color.blue
        case .code: return Color.green
        case .creative: return Color.purple
        case .work: return Color.orange
        case .personal: return Color.pink
        case .study: return Color.yellow
        }
    }
    
    var hexColor: String {
        switch self {
        case .iaModels: return "#007AFF"
        case .code: return "#34C759"
        case .creative: return "#AF52DE"
        case .work: return "#FF9500"
        case .personal: return "#FF2D92"
        case .study: return "#FFCC00"
        }
    }
    
    var icon: String {
        switch self {
        case .iaModels: return "brain.head.profile"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .creative: return "paintbrush.pointed"
        case .work: return "briefcase"
        case .personal: return "heart"
        case .study: return "book"
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
