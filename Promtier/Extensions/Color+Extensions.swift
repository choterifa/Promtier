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
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Pequeña"
        case .medium: return "Mediana"
        case .large: return "Grande"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        }
    }
}

// MARK: - AppLanguage Enum

enum AppLanguage: String, CaseIterable {
    case spanish = "es"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    var locale: Locale {
        switch self {
        case .spanish: return Locale(identifier: "es")
        case .english: return Locale(identifier: "en")
        }
    }
}
