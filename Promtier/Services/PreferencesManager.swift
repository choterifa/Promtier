//
//  PreferencesManager.swift
//  Promtier
//
//  SERVICIO: Gestión de preferencias y configuración de la app
//  Created by Carlos on 15/03/26.
//

import Foundation
import SwiftUI
import Combine
import AppKit

// SERVICIO: Gestión centralizada de preferencias con UserDefaults
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Apariencia
    
    @Published var appearance: AppAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: "appearance")
        }
    }
    
    @Published var fontSize: FontSize {
        didSet {
            userDefaults.set(fontSize.rawValue, forKey: "fontSize")
        }
    }
    
    // MARK: - Comportamiento
    
    @Published var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: "launchAtLogin")
            // TODO: Implementar launch at login cuando MenuBarManager esté disponible
            // MenuBarManager.shared.setLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var closeOnOutsideClick: Bool {
        didSet {
            userDefaults.set(closeOnOutsideClick, forKey: "closeOnOutsideClick")
        }
    }
    
    // MARK: - Sonidos y Hápticos
    
    @Published var soundEnabled: Bool {
        didSet {
            userDefaults.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    @Published var hapticFeedback: Bool {
        didSet {
            userDefaults.set(hapticFeedback, forKey: "hapticFeedback")
        }
    }
    
    // MARK: - Atajos de Teclado
    
    @Published var globalShortcutEnabled: Bool {
        didSet {
            userDefaults.set(globalShortcutEnabled, forKey: "globalShortcutEnabled")
        }
    }
    
    // MARK: - Idioma
    
    @Published var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: "language")
        }
    }
    
    // MARK: - Datos y Privacidad
    
    @Published var showInDock: Bool {
        didSet {
            userDefaults.set(showInDock, forKey: "showInDock")
        }
    }
    
    @Published var useAccentColor: Bool {
        didSet {
            userDefaults.set(useAccentColor, forKey: "useAccentColor")
        }
    }
    
    @Published var accentColor: Color {
        didSet {
            userDefaults.set(accentColor.toHex(), forKey: "accentColor")
        }
    }
    
    @Published var showCopyNotifications: Bool {
        didSet {
            userDefaults.set(showCopyNotifications, forKey: "showCopyNotifications")
        }
    }
    
    @Published var showUsageNotifications: Bool {
        didSet {
            userDefaults.set(showUsageNotifications, forKey: "showUsageNotifications")
        }
    }
    
    @Published var icloudSyncEnabled: Bool {
        didSet {
            userDefaults.set(icloudSyncEnabled, forKey: "icloudSyncEnabled")
        }
    }
    
    private init() {
        // Inicializar valores desde UserDefaults o defaults
        self.appearance = AppAppearance(rawValue: userDefaults.string(forKey: "appearance") ?? "system") ?? .system
        self.fontSize = FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "medium") ?? .medium
        self.launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        self.closeOnOutsideClick = userDefaults.bool(forKey: "closeOnOutsideClick")
        self.soundEnabled = userDefaults.bool(forKey: "soundEnabled")
        self.hapticFeedback = userDefaults.bool(forKey: "hapticFeedback")
        self.globalShortcutEnabled = userDefaults.bool(forKey: "globalShortcutEnabled")
        self.language = AppLanguage(rawValue: userDefaults.string(forKey: "language") ?? "es") ?? .spanish
        
        // Nuevas propiedades
        self.showInDock = userDefaults.bool(forKey: "showInDock")
        self.useAccentColor = userDefaults.bool(forKey: "useAccentColor")
        self.showCopyNotifications = userDefaults.bool(forKey: "showCopyNotifications")
        self.showUsageNotifications = userDefaults.bool(forKey: "showUsageNotifications")
        self.icloudSyncEnabled = userDefaults.bool(forKey: "icloudSyncEnabled")
        
        // Color de acento
        if let colorHex = userDefaults.string(forKey: "accentColor") {
            self.accentColor = Color(hex: colorHex)
        } else {
            self.accentColor = .blue
        }
        
        // Aplicar configuración inicial
        applyInitialSettings()
    }
    
    // MARK: - Métodos de Configuración
    
    /// Aplica configuración inicial al iniciar
    private func applyInitialSettings() {
        // Configurar apariencia
        switch appearance {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    /// Restablece todas las preferencias a valores por defecto
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        
        // Recargar valores por defecto
        objectWillChange.send()
        
        self.appearance = .system
        self.fontSize = .medium
        self.launchAtLogin = false
        self.closeOnOutsideClick = true
        self.soundEnabled = true
        self.hapticFeedback = true
        self.globalShortcutEnabled = true
        self.language = .spanish
        
        // Nuevas propiedades por defecto
        self.showInDock = false
        self.useAccentColor = true
        self.showCopyNotifications = true
        self.showUsageNotifications = false
        self.icloudSyncEnabled = false
        self.accentColor = .blue
        
        applyInitialSettings()
    }
    
    // MARK: - Exportar/Importar Configuración
    
    /// Exporta configuración actual a JSON
    func exportConfiguration() -> [String: Any] {
        return [
            "appearance": appearance.rawValue,
            "fontSize": fontSize.rawValue,
            "launchAtLogin": launchAtLogin,
            "closeOnOutsideClick": closeOnOutsideClick,
            "soundEnabled": soundEnabled,
            "hapticFeedback": hapticFeedback,
            "globalShortcutEnabled": globalShortcutEnabled,
            "language": language.rawValue,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        ]
    }
    
    /// Importa configuración desde diccionario
    func importConfiguration(_ config: [String: Any]) -> Bool {
        guard let version = config["version"] as? String else { return false }
        
        // Validar compatibilidad de versión (simple)
        if version.hasPrefix("1.") {
            objectWillChange.send()
            
            if let appearanceRaw = config["appearance"] as? String {
                appearance = AppAppearance(rawValue: appearanceRaw) ?? .system
            }
            
            if let fontSizeRaw = config["fontSize"] as? String {
                fontSize = FontSize(rawValue: fontSizeRaw) ?? .medium
            }
            
            if let launchAtLogin = config["launchAtLogin"] as? Bool {
                self.launchAtLogin = launchAtLogin
            }
            
            if let closeOnOutsideClick = config["closeOnOutsideClick"] as? Bool {
                self.closeOnOutsideClick = closeOnOutsideClick
            }
            
            if let soundEnabled = config["soundEnabled"] as? Bool {
                self.soundEnabled = soundEnabled
            }
            
            if let hapticFeedback = config["hapticFeedback"] as? Bool {
                self.hapticFeedback = hapticFeedback
            }
            
            if let globalShortcutEnabled = config["globalShortcutEnabled"] as? Bool {
                self.globalShortcutEnabled = globalShortcutEnabled
            }
            
            if let languageRaw = config["language"] as? String {
                language = AppLanguage(rawValue: languageRaw) ?? .spanish
            }
            
            applyInitialSettings()
            return true
        }
        
        return false
    }
}
