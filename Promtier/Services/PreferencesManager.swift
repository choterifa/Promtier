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

struct DraftPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    let title: String
    let instruction: String
    let icon: String
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

    @Published var autoHideSidebarInGallery: Bool {
        didSet {
            userDefaults.set(autoHideSidebarInGallery, forKey: "autoHideSidebarInGallery")
        }
    }

    @Published var sidebarWidth: CGFloat {
        didSet {
            userDefaults.set(sidebarWidth, forKey: "sidebarWidth")
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

    @Published var autoCopyDraft: Bool {
        didSet {
            userDefaults.set(autoCopyDraft, forKey: "autoCopyDraft")
        }
    }

    @Published var enableTrackpadCarousel: Bool {
        didSet {
            userDefaults.set(enableTrackpadCarousel, forKey: "enableTrackpadCarousel")
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
    
    @Published var windowWidth: CGFloat {
        didSet {
            userDefaults.set(Double(windowWidth), forKey: "windowWidth")
        }
    }
    @Published var windowHeight: CGFloat {
        didSet {
            userDefaults.set(Double(windowHeight), forKey: "windowHeight")
        }
    }
    
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
    
    @Published var fastAddHotkeyCode: Int {
        didSet {
            userDefaults.set(fastAddHotkeyCode, forKey: "fastAddHotkeyCode")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var fastAddHotkeyModifiers: Int {
        didSet {
            userDefaults.set(fastAddHotkeyModifiers, forKey: "fastAddHotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var categoryHotkeyCode: Int {
        didSet {
            userDefaults.set(categoryHotkeyCode, forKey: "categoryHotkeyCode")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var categoryHotkeyModifiers: Int {
        didSet {
            userDefaults.set(categoryHotkeyModifiers, forKey: "categoryHotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var newPromptHotkeyCode: Int {
        didSet {
            userDefaults.set(newPromptHotkeyCode, forKey: "newPromptHotkeyCode")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var newPromptHotkeyModifiers: Int {
        didSet {
            userDefaults.set(newPromptHotkeyModifiers, forKey: "newPromptHotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var aiDraftHotkeyCode: Int {
        didSet {
            userDefaults.set(aiDraftHotkeyCode, forKey: "aiDraftHotkeyCode")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var aiDraftHotkeyModifiers: Int {
        didSet {
            userDefaults.set(aiDraftHotkeyModifiers, forKey: "aiDraftHotkeyModifiers")
            ShortcutManager.shared.setupCarbonHotKey()
        }
    }
    
    @Published var draftPresets: [DraftPreset] {
        didSet {
            if let data = try? JSONEncoder().encode(draftPresets) {
                userDefaults.set(data, forKey: "draftPresets")
            }
        }
    }
    
    // MARK: - Idioma
    
    @Published var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: "language")
        }
    }
    
    // "auto" = detect from input, "en" = force English, "es" = force Spanish
    @Published var aiResponseLanguage: String {
        didSet {
            userDefaults.set(aiResponseLanguage, forKey: "aiResponseLanguage")
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
    
    @Published var hasSeenOnboarding: Bool {
        didSet {
            userDefaults.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
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
            _ = KeychainManager.shared.save(key: "geminiAPIKey", data: geminiAPIKey)
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

    @Published var openAIEnabled: Bool {
        didSet {
            userDefaults.set(openAIEnabled, forKey: "openAIEnabled")
        }
    }
    
    @Published var openAIApiKey: String {
        didSet {
            _ = KeychainManager.shared.save(key: "openAIApiKey", data: openAIApiKey)
        }
    }
    
    @Published var openAIDefaultModel: String {
        didSet {
            userDefaults.set(openAIDefaultModel, forKey: "openAIDefaultModel")
        }
    }
    
    /// Carpetas pineadas en el sidebar (máx. 3), persistidas por nombre
    @Published var pinnedFolderNames: [String] {
        didSet {
            userDefaults.set(pinnedFolderNames, forKey: "pinnedFolderNames")
        }
    }
    
    func isPinned(_ folderName: String) -> Bool {
        pinnedFolderNames.contains(folderName)
    }
    
    func togglePin(_ folderName: String) {
        if let idx = pinnedFolderNames.firstIndex(of: folderName) {
            pinnedFolderNames.remove(at: idx)
        } else if pinnedFolderNames.count < 3 {
            pinnedFolderNames.insert(folderName, at: 0)
        }
    }
     private init() {
        // 1. Inicializar todas las propiedades SIN usar self si es posible,
        // o simplemente inicializar cada una antes de cualquier llamada a método.
        
        // 1. Initial property assignments (MUST NOT read other properties via self yet)
        self.appearance = AppAppearance(rawValue: userDefaults.string(forKey: "appearance") ?? "light") ?? .light
        self.fontSize = FontSize(rawValue: userDefaults.string(forKey: "fontSize") ?? "medium") ?? .medium
        self.launchAtLogin = userDefaults.bool(forKey: "launchAtLogin")
        self.showSidebar = userDefaults.object(forKey: "showSidebar") == nil ? true : userDefaults.bool(forKey: "showSidebar")
        self.isGridView = userDefaults.bool(forKey: "isGridView")
        self.autoHideSidebarInGallery = userDefaults.object(forKey: "autoHideSidebarInGallery") == nil ? true : userDefaults.bool(forKey: "autoHideSidebarInGallery")
        let savedSidebarWidth = userDefaults.double(forKey: "sidebarWidth")
        self.sidebarWidth = savedSidebarWidth > 0 ? min(350, max(200, CGFloat(savedSidebarWidth))) : 220
        self.closeOnCopy = userDefaults.bool(forKey: "closeOnCopy")
        self.autoPaste = userDefaults.bool(forKey: "autoPaste")
        self.clipboardSuggestions = userDefaults.object(forKey: "clipboardSuggestions") == nil ? true : userDefaults.bool(forKey: "clipboardSuggestions")
        self.autoCopyDraft = userDefaults.object(forKey: "autoCopyDraft") == nil ? true : userDefaults.bool(forKey: "autoCopyDraft")
        self.enableTrackpadCarousel = userDefaults.object(forKey: "enableTrackpadCarousel") == nil ? true : userDefaults.bool(forKey: "enableTrackpadCarousel")
        self.onlySuggestFromBrowsers = true
        self.customAllowedAppBundleIDs = Set(userDefaults.array(forKey: "customAllowedAppBundleIDs") as? [String] ?? [])
        
        let savedWidth = userDefaults.object(forKey: "windowWidth") as? Double
        self.windowWidth = (savedWidth != nil && savedWidth! > 0) ? min(900, max(500, CGFloat(savedWidth!))) : 800
        let savedHeight = userDefaults.object(forKey: "windowHeight") as? Double
        self.windowHeight = (savedHeight != nil && savedHeight! > 0) ? min(750, max(450, CGFloat(savedHeight!))) : 570
        
        // Non-persistent state defaults
        self.isResizingVisible = false
        self.previewWidth = 800  // Initial defaults
        self.previewHeight = 570
        
        self.soundEnabled = userDefaults.bool(forKey: "soundEnabled")
        self.hapticFeedbackEnabled = userDefaults.object(forKey: "hapticFeedbackEnabled") == nil ? true : userDefaults.bool(forKey: "hapticFeedbackEnabled")
        self.globalShortcutEnabled = userDefaults.bool(forKey: "globalShortcutEnabled")
        self.hotkeyCode = userDefaults.object(forKey: "hotkeyCode") as? Int ?? 35
        self.hotkeyModifiers = userDefaults.object(forKey: "hotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.omniHotkeyCode = userDefaults.object(forKey: "omniHotkeyCode") as? Int ?? 49
        self.omniHotkeyModifiers = userDefaults.object(forKey: "omniHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.fastAddHotkeyCode = userDefaults.object(forKey: "fastAddHotkeyCode") as? Int ?? 3
        self.fastAddHotkeyModifiers = userDefaults.object(forKey: "fastAddHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.categoryHotkeyCode = userDefaults.object(forKey: "categoryHotkeyCode") as? Int ?? 45
        self.categoryHotkeyModifiers = userDefaults.object(forKey: "categoryHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .option]).rawValue)
        self.newPromptHotkeyCode = userDefaults.object(forKey: "newPromptHotkeyCode") as? Int ?? 0
        self.newPromptHotkeyModifiers = userDefaults.object(forKey: "newPromptHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.aiDraftHotkeyCode = userDefaults.object(forKey: "aiDraftHotkeyCode") as? Int ?? 34
        self.aiDraftHotkeyModifiers = userDefaults.object(forKey: "aiDraftHotkeyModifiers") as? Int ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        
        self.language = AppLanguage(rawValue: userDefaults.string(forKey: "language") ?? "en") ?? .english
        self.aiResponseLanguage = userDefaults.string(forKey: "aiResponseLanguage") ?? "auto"
        self.showInDock = userDefaults.bool(forKey: "showInDock")
        self.showCopyNotifications = userDefaults.object(forKey: "showCopyNotifications") == nil ? true : userDefaults.bool(forKey: "showCopyNotifications")
        self.showUsageNotifications = userDefaults.bool(forKey: "showUsageNotifications")
        self.icloudSyncEnabled = userDefaults.bool(forKey: "icloudSyncEnabled")
        // Se eliminó suppressAccessibilityWarning
        self.hasSeenOnboarding = userDefaults.bool(forKey: "hasSeenOnboarding")
        self.isPremiumActive = userDefaults.bool(forKey: "isPremiumActive")
        self.visualEffectsEnabled = userDefaults.object(forKey: "visualEffectsEnabled") == nil ? true : userDefaults.bool(forKey: "visualEffectsEnabled")
        self.previewImagesFirst = userDefaults.object(forKey: "previewImagesFirst") as? Bool ?? true
        self.geminiEnabled = userDefaults.object(forKey: "geminiEnabled") as? Bool ?? false
        self.ghostTipsEnabled = userDefaults.object(forKey: "ghostTipsEnabled") == nil ? true : userDefaults.bool(forKey: "ghostTipsEnabled")
        self.gestureHintsEnabled = userDefaults.object(forKey: "gestureHintsEnabled") == nil ? true : userDefaults.bool(forKey: "gestureHintsEnabled")
        self.disableImageAnimations = userDefaults.bool(forKey: "disableImageAnimations")
        self.showAdvancedFields = userDefaults.object(forKey: "showAdvancedFields") == nil ? true : userDefaults.bool(forKey: "showAdvancedFields")
        self.isHaloEffectEnabled = userDefaults.object(forKey: "isHaloEffectEnabled") == nil ? true : userDefaults.bool(forKey: "isHaloEffectEnabled")
        self.geminiAPIKey = KeychainManager.shared.read(key: "geminiAPIKey") ?? ""
        self.geminiDefaultModel = userDefaults.string(forKey: "geminiDefaultModel") ?? "gemini-2.5-flash"
        self.preferredAIService = AIService(rawValue: userDefaults.string(forKey: "preferredAIService") ?? "openai") ?? .openai
        self.openAIEnabled = userDefaults.object(forKey: "openAIEnabled") as? Bool ?? true
        self.openAIApiKey = KeychainManager.shared.read(key: "openAIApiKey") ?? ""
        self.openAIDefaultModel = userDefaults.string(forKey: "openAIDefaultModel") ?? "gpt-4o"
        self.pinnedFolderNames = userDefaults.stringArray(forKey: "pinnedFolderNames") ?? []
        self.snippets = [] // Assigned below
        
        if let data = userDefaults.data(forKey: "draftPresets"),
           let decoded = try? JSONDecoder().decode([DraftPreset].self, from: data) {
            self.draftPresets = decoded
        } else {
            self.draftPresets = [
                DraftPreset(title: "Sarcástico", instruction: "Hacerlo sarcástico e ingenioso", icon: "face.smiling"),
                DraftPreset(title: "Email Pro", instruction: "Reescribir como un email profesional", icon: "envelope.fill"),
                DraftPreset(title: "Markdown", instruction: "Convertir a formato Markdown limpio", icon: "text.justify")
            ]
        }
        
        // 2. NOW ALL properties are initialized. We can use self.
        
        // Derived state
        self.previewWidth = self.windowWidth
        self.previewHeight = self.windowHeight
        
        let seedLang = self.language
        if let data = userDefaults.data(forKey: "savedSnippets"),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            self.snippets = decoded
        } else {
            self.snippets = [
                Snippet(title: "snippet_signature_title".localized(for: seedLang), content: "snippet_signature_content".localized(for: seedLang), shortcut: "snippet_signature_shortcut".localized(for: seedLang)),
                Snippet(title: "snippet_bug_title".localized(for: seedLang), content: "snippet_bug_content".localized(for: seedLang), shortcut: "snippet_bug_shortcut".localized(for: seedLang)),
                Snippet(title: "snippet_review_title".localized(for: seedLang), content: "snippet_review_content".localized(for: seedLang), shortcut: "snippet_review_shortcut".localized(for: seedLang))
            ]
        }
        
        normalizeAISettings()
        applyAppearance()
        applyDockPolicy()
        applyLaunchAtLogin()
    }

    private func normalizeAISettings() {
        // Exclusividad: solo un proveedor activo a la vez.
        if openAIEnabled && geminiEnabled {
            switch preferredAIService {
            case .gemini:
                openAIEnabled = false
            case .openai:
                geminiEnabled = false
            }
        } else if openAIEnabled {
            preferredAIService = .openai
        } else if geminiEnabled {
            preferredAIService = .gemini
        }
    }
    
    // MARK: - Métodos de Configuración
    
    /// Configura el inicio automático al iniciar sesión
    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
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
        self.autoHideSidebarInGallery = true
        self.closeOnCopy = true
        self.soundEnabled = true
        self.hapticFeedbackEnabled = true
        self.globalShortcutEnabled = true
        self.hotkeyCode = 35
        self.hotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.omniHotkeyCode = 49
        self.categoryHotkeyCode = 45
        self.categoryHotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .option]).rawValue)
        self.newPromptHotkeyCode = 0
        self.newPromptHotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.aiDraftHotkeyCode = 2
        self.aiDraftHotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        self.language = .english
        self.autoPaste = false
        self.clipboardSuggestions = true
        self.onlySuggestFromBrowsers = true
        self.windowWidth = 800
        self.windowHeight = 570
        self.enableTrackpadCarousel = true
        self.autoCopyDraft = true
        
        // Nuevas propiedades por defecto
        self.showInDock = false
        self.showCopyNotifications = true
        self.showUsageNotifications = false
        self.icloudSyncEnabled = false
        self.hasSeenOnboarding = false
        self.isPremiumActive = false
        self.ghostTipsEnabled = true
        self.gestureHintsEnabled = true
        self.previewImagesFirst = true
        self.disableImageAnimations = false
        self.showAdvancedFields = true
        self.isHaloEffectEnabled = true
        self.geminiEnabled = false
        self.geminiAPIKey = ""
        _ = KeychainManager.shared.delete(key: "geminiAPIKey")
        self.geminiDefaultModel = "gemini-2.5-flash"
        self.preferredAIService = .openai
        self.openAIEnabled = true
        self.openAIApiKey = ""
        _ = KeychainManager.shared.delete(key: "openAIApiKey")
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
    
    // MARK: - Helpers de Atajos
    
    /// Devuelve una cadena legible para el atajo (ej: "⌘⇧N")
    func shortcutDisplayString(keyCode: Int, modifiers: Int) -> String {
        if keyCode == -1 { return "" }
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        
        // Convertir keyCode a carácter legible usando CGEvent (más robusto)
        let keyStr: String
        switch keyCode {
        case 36: keyStr = "↩"
        case 48: keyStr = "⇥"
        case 49: keyStr = "Space"
        case 51: keyStr = "⌫"
        case 53: keyStr = "⎋"
        case 123: keyStr = "←"
        case 124: keyStr = "→"
        case 125: keyStr = "↓"
        case 126: keyStr = "↑"
        default:
            let source = CGEventSource(stateID: .combinedSessionState)
            if let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
               let nsEvent = NSEvent(cgEvent: cgEvent),
               let chars = nsEvent.charactersIgnoringModifiers, !chars.isEmpty {
                keyStr = chars.uppercased()
            } else {
                keyStr = "\(keyCode)"
            }
        }
        
        return result + keyStr
    }
}

// MARK: - Helper de Seguridad

class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceIdentifier: String
    
    private init() {
        self.serviceIdentifier = Bundle.main.bundleIdentifier ?? "app.promtier.keys"
    }
    
    func save(key: String, data: String) -> OSStatus {
        guard let dataFromString = data.data(using: .utf8, allowLossyConversion: false) else {
            return errSecParam
        }
        
        let _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : serviceIdentifier,
            kSecAttrAccount as String : key,
            kSecValueData as String   : dataFromString,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : serviceIdentifier,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        // --- Migración desde llaves antiguas sin 'kSecAttrService' ---
        if status == errSecItemNotFound {
            let legacyQuery: [String: Any] = [
                kSecClass as String       : kSecClassGenericPassword,
                kSecAttrAccount as String : key,
                kSecReturnData as String  : kCFBooleanTrue!,
                kSecMatchLimit as String  : kSecMatchLimitOne
            ]
            
            var legacyRef: AnyObject?
            status = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyRef)
            
            if status == errSecSuccess, let legacyData = legacyRef as? Data, let legacyStr = String(data: legacyData, encoding: .utf8) {
                // Migrar a la nueva estructura segura borrando la insegura
                SecItemDelete(legacyQuery as CFDictionary)
                _ = self.save(key: key, data: legacyStr)
                return legacyStr
            }
        }
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let result = String(data: retrievedData, encoding: .utf8) {
                return result
            }
        }
        return nil
    }
    
    func delete(key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : serviceIdentifier,
            kSecAttrAccount as String : key
        ]
        
        return SecItemDelete(query as CFDictionary)
    }
}
