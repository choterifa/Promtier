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
import ServiceManagement

// SERVICIO: Gestión centralizada de preferencias con UserDefaults
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Apariencia
    
    @Published var appearance: AppAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
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
            applyLaunchAtLogin()
        }
    }
    
    @Published var showSidebar: Bool {
        didSet {
            userDefaults.set(showSidebar, forKey: "showSidebar")
        }
    }
    
    @Published var closeOnCopy: Bool {
        didSet {
            userDefaults.set(closeOnCopy, forKey: "closeOnCopy")
        }
    }
    
    @Published var autoPaste: Bool {
        didSet {
            userDefaults.set(autoPaste, forKey: "autoPaste")
        }
    }
    
    @Published var windowWidth: CGFloat
    @Published var windowHeight: CGFloat
    
    /// Guarda las dimensiones en UserDefaults (llamar al terminar de redimensionar)
    func saveWindowDimensions() {
        userDefaults.set(Double(windowWidth), forKey: "windowWidth")
        userDefaults.set(Double(windowHeight), forKey: "windowHeight")
    }
    
    // MARK: - Estado de Redimensionado (No persistente)
    @Published var isResizingVisible: Bool = false
    @Published var previewWidth: CGFloat = 0
    @Published var previewHeight: CGFloat = 0
    
    // MARK: - Sonidos
    
    @Published var soundEnabled: Bool {
        didSet {
            userDefaults.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            userDefaults.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
        }
    }
    
    // MARK: - Atajos de Teclado
    
    @Published var globalShortcutEnabled: Bool {
        didSet {
            userDefaults.set(globalShortcutEnabled, forKey: "globalShortcutEnabled")
        }
    }
    
    @Published var hotkeyCode: Int {
        didSet {
            userDefaults.set(hotkeyCode, forKey: "hotkeyCode")
        }
    }
    
    @Published var hotkeyModifiers: Int {
        didSet {
            userDefaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
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
            applyDockPolicy()
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
    
    @Published var suppressAccessibilityWarning: Bool {
        didSet {
            userDefaults.set(suppressAccessibilityWarning, forKey: "suppressAccessibilityWarning")
        }
    }
    
    @Published var isPremiumActive: Bool {
        didSet {
            userDefaults.set(isPremiumActive, forKey: "isPremiumActive")
        }
    }
    
    @Published var snippets: [Snippet] = [] {
        didSet {
            if let encoded = try? JSONEncoder().encode(snippets) {
                userDefaults.set(encoded, forKey: "savedSnippets")
            }
        }
    }
    
    @Published var visualEffectsEnabled: Bool {
        didSet {
            userDefaults.set(visualEffectsEnabled, forKey: "visualEffectsEnabled")
        }
    }
    
    @Published var previewImagesFirst: Bool {
        didSet {
            userDefaults.set(previewImagesFirst, forKey: "previewImagesFirst")
        }
    }
    
    @Published var appleIntelligenceEnabled: Bool {
        didSet {
            userDefaults.set(appleIntelligenceEnabled, forKey: "appleIntelligenceEnabled")
        }
    }
    
    private init() {
        // Inicializar valores desde UserDefaults o defaults
        self.appearance = AppAppearance(rawValue: userDefaults.string(forKey: "appearance") ?? "system") ?? .system
        self.fontSize = FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "medium") ?? .medium
        self.launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        // Sidebar visible por defecto
        self.showSidebar = userDefaults.object(forKey: "showSidebar") as? Bool ?? true
        self.closeOnCopy = userDefaults.bool(forKey: "closeOnCopy")
        self.soundEnabled = userDefaults.bool(forKey: "soundEnabled")
        
        // Háptica por defecto en true
        if userDefaults.object(forKey: "hapticFeedbackEnabled") != nil {
            self.hapticFeedbackEnabled = userDefaults.bool(forKey: "hapticFeedbackEnabled")
        } else {
            self.hapticFeedbackEnabled = true
        }
        
        self.globalShortcutEnabled = userDefaults.bool(forKey: "globalShortcutEnabled")
        
        // Atajo por defecto: ⌘⇧P (KeyCode 35, Command + Shift)
        self.hotkeyCode = userDefaults.object(forKey: "hotkeyCode") as? Int ?? 35
        self.hotkeyModifiers = userDefaults.object(forKey: "hotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.language = AppLanguage(rawValue: userDefaults.string(forKey: "language") ?? "es") ?? .spanish
        self.autoPaste = userDefaults.bool(forKey: "autoPaste")
        
        // Dimensiones de ventana (Defaults: 690x540, Max: 900x750, Min: 500x450)
        let savedWidth = userDefaults.double(forKey: "windowWidth")
        self.windowWidth = savedWidth > 0 ? min(900, max(500, CGFloat(savedWidth))) : 690
        
        let savedHeight = userDefaults.double(forKey: "windowHeight")
        self.windowHeight = savedHeight > 0 ? min(750, max(450, CGFloat(savedHeight))) : 540
        
        // Nuevas propiedades
        self.showInDock = userDefaults.bool(forKey: "showInDock")
        self.showCopyNotifications = userDefaults.bool(forKey: "showCopyNotifications")
        self.showUsageNotifications = userDefaults.bool(forKey: "showUsageNotifications")
        self.icloudSyncEnabled = userDefaults.bool(forKey: "icloudSyncEnabled")
        self.suppressAccessibilityWarning = userDefaults.bool(forKey: "suppressAccessibilityWarning")
        self.isPremiumActive = userDefaults.bool(forKey: "isPremiumActive")
        
        // Efectos visuales por defecto en true
        if userDefaults.object(forKey: "visualEffectsEnabled") != nil {
            self.visualEffectsEnabled = userDefaults.bool(forKey: "visualEffectsEnabled")
        } else {
            self.visualEffectsEnabled = true
        }
        
        // Imágenes primero por defecto
        self.previewImagesFirst = userDefaults.object(forKey: "previewImagesFirst") as? Bool ?? true
        
        // Apple Intelligence por defecto en true
        self.appleIntelligenceEnabled = userDefaults.object(forKey: "appleIntelligenceEnabled") as? Bool ?? true
        
        if let data = userDefaults.data(forKey: "savedSnippets"),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            self.snippets = decoded
        } else {
            // Snippets de ejemplo
            self.snippets = [
                Snippet(title: "Firma Profesional", content: "Saludos cordiales,\nEquipo Promtier", shortcut: "firma"),
                Snippet(title: "Plantilla Bug", content: "**Descripción:**\n**Pasos a reproducir:**\n1. \n2. \n**Resultado esperado:**", shortcut: "bug"),
                Snippet(title: "Revisión Rápida", content: "Por favor revisa este código y optimízalo para SwiftUI:", shortcut: "revisar")
            ]
        }
        
        // Aplicar configuración inicial
        applyAppearance()
        applyDockPolicy()
        applyLaunchAtLogin()
    }
    
    // MARK: - Métodos de Configuración
    
    /// Configura el inicio automático al iniciar sesión
    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
                    print("✅ Inicio automático activado")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    print("✅ Inicio automático desactivado")
                }
            }
        } catch {
            print("❌ Error configurando inicio automático: \(error)")
        }
    }
    
    /// Configura la visibilidad en el Dock
    private func applyDockPolicy() {
        DispatchQueue.main.async {
            let policy: NSApplication.ActivationPolicy = self.showInDock ? .regular : .accessory
            NSApp.setActivationPolicy(policy)
            
            // Si se muestra en el Dock, asegurar que aparezca al frente
            if self.showInDock {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    /// Aplica la apariencia seleccionada al sistema
    private func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearance {
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case .system:
                NSApp.appearance = nil
            }
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
        self.showSidebar = true
        self.closeOnCopy = true
        self.soundEnabled = true
        self.hapticFeedbackEnabled = true
        self.globalShortcutEnabled = true
        self.hotkeyCode = 35
        self.hotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.language = .spanish
        self.autoPaste = false
        self.windowWidth = 690
        self.windowHeight = 540
        
        // Nuevas propiedades por defecto
        self.showInDock = false
        self.showCopyNotifications = true
        self.showUsageNotifications = false
        self.icloudSyncEnabled = false
        self.suppressAccessibilityWarning = false
        self.isPremiumActive = false
        self.appleIntelligenceEnabled = true
        self.previewImagesFirst = true
        
        applyAppearance()
    }
    
    // MARK: - Exportar/Importar Configuración
    
    /// Exporta configuración actual a JSON
    func exportConfiguration() -> [String: Any] {
        return [
            "appearance": appearance.rawValue,
            "fontSize": fontSize.rawValue,
            "launchAtLogin": launchAtLogin,
            "showSidebar": showSidebar,
            "windowWidth": Double(windowWidth),
            "windowHeight": Double(windowHeight),
            "closeOnCopy": closeOnCopy,
            "soundEnabled": soundEnabled,
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
            
            if let closeOnCopy = config["closeOnCopy"] as? Bool {
                self.closeOnCopy = closeOnCopy
            }
            
            if let soundEnabled = config["soundEnabled"] as? Bool {
                self.soundEnabled = soundEnabled
            }
            
            if let globalShortcutEnabled = config["globalShortcutEnabled"] as? Bool {
                self.globalShortcutEnabled = globalShortcutEnabled
            }
            
            if let languageRaw = config["language"] as? String {
                language = AppLanguage(rawValue: languageRaw) ?? .spanish
            }
            
            if let showSidebar = config["showSidebar"] as? Bool {
                self.showSidebar = showSidebar
            }
            
            if let width = config["windowWidth"] as? Double {
                self.windowWidth = CGFloat(width)
            }
            
            if let height = config["windowHeight"] as? Double {
                self.windowHeight = CGFloat(height)
            }
            
            applyAppearance()
            return true
        }
        
        return false
    }
}
