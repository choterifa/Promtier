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

enum AIService: String, Codable, CaseIterable {
    case gemini = "gemini"
    case openai = "openai"
}

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
    
    @Published var isGridView: Bool {
        didSet {
            userDefaults.set(isGridView, forKey: "isGridView")
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
    
    @Published var clipboardSuggestions: Bool {
        didSet {
            userDefaults.set(clipboardSuggestions, forKey: "clipboardSuggestions")
        }
    }
    
    @Published var onlySuggestFromBrowsers: Bool {
        didSet {
            userDefaults.set(onlySuggestFromBrowsers, forKey: "onlySuggestFromBrowsers")
        }
    }
    
    let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser",   // Arc Browser
        "com.vivaldi.Vivaldi",
        "com.kagi.orion"
    ]
    
    @Published var customAllowedAppBundleIDs: Set<String> {
        didSet {
            userDefaults.set(Array(customAllowedAppBundleIDs), forKey: "customAllowedAppBundleIDs")
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
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var hotkeyModifiers: Int {
        didSet {
            userDefaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var omniHotkeyCode: Int {
        didSet {
            userDefaults.set(omniHotkeyCode, forKey: "omniHotkeyCode")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var omniHotkeyModifiers: Int {
        didSet {
            userDefaults.set(omniHotkeyModifiers, forKey: "omniHotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
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
    
    @Published var geminiEnabled: Bool {
        didSet {
            userDefaults.set(geminiEnabled, forKey: "geminiEnabled")
        }
    }
    
    @Published var geminiDefaultModel: String {
        didSet {
            userDefaults.set(geminiDefaultModel, forKey: "geminiDefaultModel")
        }
    }
    
    @Published var geminiAPIKey: String {
        didSet {
            userDefaults.set(geminiAPIKey, forKey: "geminiAPIKey")
        }
    }
    
    @Published var ghostTipsEnabled: Bool {
        didSet {
            userDefaults.set(ghostTipsEnabled, forKey: "ghostTipsEnabled")
        }
    }
    
    @Published var gestureHintsEnabled: Bool {
        didSet {
            userDefaults.set(gestureHintsEnabled, forKey: "gestureHintsEnabled")
        }
    }
    
    @Published var disableImageAnimations: Bool {
        didSet {
            userDefaults.set(disableImageAnimations, forKey: "disableImageAnimations")
        }
    }
    
    @Published var showAdvancedFields: Bool {
        didSet {
            userDefaults.set(showAdvancedFields, forKey: "showAdvancedFields")
        }
    }
    
    @Published var isHaloEffectEnabled: Bool {
        didSet {
            userDefaults.set(isHaloEffectEnabled, forKey: "isHaloEffectEnabled")
        }
    }
    
    @Published var preferredAIService: AIService {
        didSet {
            userDefaults.set(preferredAIService.rawValue, forKey: "preferredAIService")
        }
    }
    
    @Published var openAIApiKey: String {
        didSet {
            userDefaults.set(openAIApiKey, forKey: "openAIApiKey")
        }
    }
    
    @Published var openAIDefaultModel: String {
        didSet {
            userDefaults.set(openAIDefaultModel, forKey: "openAIDefaultModel")
        }
    }
    
    private init() {
        // Inicializar valores desde UserDefaults o defaults
        self.appearance = AppAppearance(rawValue: userDefaults.string(forKey: "appearance") ?? "light") ?? .light
        self.fontSize = FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "medium") ?? .medium
        self.launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        // Sidebar visible por defecto
        self.showSidebar = userDefaults.object(forKey: "showSidebar") as? Bool ?? true
        // Vista de grid (tarjetas) por defecto en false
        self.isGridView = userDefaults.bool(forKey: "isGridView")
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
        
        // Atajo Omni-Search por defecto: ⌘⇧Space (KeyCode 49, Command + Shift)
        self.omniHotkeyCode = userDefaults.object(forKey: "omniHotkeyCode") as? Int ?? 49
        self.omniHotkeyModifiers = userDefaults.object(forKey: "omniHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        
        self.language = AppLanguage(rawValue: userDefaults.string(forKey: "language") ?? "en") ?? .english
        self.autoPaste = userDefaults.bool(forKey: "autoPaste")
        
        // Sugerencias de portapapeles: Solo desde navegadores y apps de la lista por defecto
        if userDefaults.object(forKey: "clipboardSuggestions") != nil {
            self.clipboardSuggestions = userDefaults.bool(forKey: "clipboardSuggestions")
        } else {
            self.clipboardSuggestions = true
        }

        // Siempre forzamos el filtrado por defecto como se solicitó
        self.onlySuggestFromBrowsers = true
        
        // Custom apps
        if let savedCustomApps = userDefaults.array(forKey: "customAllowedAppBundleIDs") as? [String] {
            self.customAllowedAppBundleIDs = Set(savedCustomApps)
        } else {
            self.customAllowedAppBundleIDs = []
        }
        
        // Dimensiones de ventana (Defaults: 800x570, Max: 900x750, Min: 500x450)
        let savedWidth = userDefaults.double(forKey: "windowWidth")
        self.windowWidth = savedWidth > 0 ? min(900, max(500, CGFloat(savedWidth))) : 800
        
        let savedHeight = userDefaults.double(forKey: "windowHeight")
        self.windowHeight = savedHeight > 0 ? min(750, max(450, CGFloat(savedHeight))) : 570
        
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
        
        self.geminiEnabled = userDefaults.object(forKey: "geminiEnabled") as? Bool ?? false
        if userDefaults.object(forKey: "ghostTipsEnabled") != nil {
            self.ghostTipsEnabled = userDefaults.bool(forKey: "ghostTipsEnabled")
        } else {
            self.ghostTipsEnabled = true
        }

        // Sugerencias de gestos por defecto en true
        if userDefaults.object(forKey: "gestureHintsEnabled") != nil {
            self.gestureHintsEnabled = userDefaults.bool(forKey: "gestureHintsEnabled")
        } else {
            self.gestureHintsEnabled = true
        }
        
        // Desactivar animaciones por defecto en false (animadas por defecto)
        self.disableImageAnimations = userDefaults.bool(forKey: "disableImageAnimations")
        
        if userDefaults.object(forKey: "showAdvancedFields") != nil {
            self.showAdvancedFields = userDefaults.bool(forKey: "showAdvancedFields")
        } else {
            self.showAdvancedFields = true
        }
        
        // Efectos de halo por defecto en true
        if userDefaults.object(forKey: "isHaloEffectEnabled") != nil {
            self.isHaloEffectEnabled = userDefaults.bool(forKey: "isHaloEffectEnabled")
        } else {
            self.isHaloEffectEnabled = true
        }
        
        if let data = userDefaults.data(forKey: "savedSnippets"),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            self.snippets = decoded
        } else {
            // Snippets de ejemplo
            self.snippets = [
                Snippet(title: NSLocalizedString("snippet_signature_title", comment: ""), content: NSLocalizedString("snippet_signature_content", comment: ""), shortcut: NSLocalizedString("snippet_signature_shortcut", comment: "")),
                Snippet(title: NSLocalizedString("snippet_bug_title", comment: ""), content: NSLocalizedString("snippet_bug_content", comment: ""), shortcut: NSLocalizedString("snippet_bug_shortcut", comment: "")),
                Snippet(title: NSLocalizedString("snippet_review_title", comment: ""), content: NSLocalizedString("snippet_review_content", comment: ""), shortcut: NSLocalizedString("snippet_review_shortcut", comment: ""))
            ]
        }
        
        // Gemini
        self.geminiEnabled = userDefaults.object(forKey: "geminiEnabled") as? Bool ?? false
        self.geminiAPIKey = userDefaults.string(forKey: "geminiAPIKey") ?? ""
        self.geminiDefaultModel = userDefaults.string(forKey: "geminiDefaultModel") ?? "gemini-1.5-flash-latest"
        
        // OpenAI
        self.preferredAIService = AIService(rawValue: userDefaults.string(forKey: "preferredAIService") ?? "openai") ?? .openai
        self.openAIApiKey = userDefaults.string(forKey: "openAIApiKey") ?? ""
        self.openAIDefaultModel = userDefaults.string(forKey: "openAIDefaultModel") ?? "gpt-4o"
        
        // Sincronizar dimensiones para el HUD
        self.previewWidth = self.windowWidth
        self.previewHeight = self.windowHeight
        
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
        if let domain = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: domain)
        }
        
        // Recargar valores por defecto
        objectWillChange.send()
        
        self.appearance = .light
        self.fontSize = .medium
        self.launchAtLogin = false
        self.showSidebar = true
        self.isGridView = false
        self.closeOnCopy = true
        self.soundEnabled = true
        self.hapticFeedbackEnabled = true
        self.globalShortcutEnabled = true
        self.hotkeyCode = 35
        self.hotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.omniHotkeyCode = 49
        self.omniHotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.language = .english
        self.autoPaste = false
        self.clipboardSuggestions = true
        self.onlySuggestFromBrowsers = true
        self.windowWidth = 800
        self.windowHeight = 570
        
        // Nuevas propiedades por defecto
        self.showInDock = false
        self.showCopyNotifications = true
        self.showUsageNotifications = false
        self.icloudSyncEnabled = false
        self.suppressAccessibilityWarning = false
        self.isPremiumActive = false
        self.ghostTipsEnabled = true
        self.gestureHintsEnabled = true
        self.previewImagesFirst = true
        self.disableImageAnimations = false
        self.showAdvancedFields = true
        self.isHaloEffectEnabled = true
        self.geminiEnabled = false
        self.geminiAPIKey = ""
        self.geminiDefaultModel = "gemini-1.5-flash-latest"
        self.preferredAIService = .openai
        self.openAIApiKey = ""
        self.openAIDefaultModel = "gpt-4o"
        
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
    
    // MARK: - App Whitelist Management
    
    func addAppToWhitelist(at url: URL) -> Bool {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return false
        }
        
        if customAllowedAppBundleIDs.contains(bundleID) { return true }
        
        customAllowedAppBundleIDs.insert(bundleID)
        return true
    }
    
    func addAppToWhitelist(bundleID: String) -> Bool {
        if customAllowedAppBundleIDs.contains(bundleID) { return true }
        customAllowedAppBundleIDs.insert(bundleID)
        return true
    }
    
    func removeAppFromWhitelist(bundleID: String) {
        customAllowedAppBundleIDs.remove(bundleID)
    }
}
