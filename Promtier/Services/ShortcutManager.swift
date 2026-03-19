//
//  ShortcutManager.swift
//  Promtier
//
//  SERVICIO: Gestión de atajos de teclado globales (simplificado)
//  Created by Carlos on 15/03/26.
//

import AppKit
import Combine
import Carbon

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var isEnabled = true
    @Published var isAccessibilityGranted = false
    
    // Eliminamos la dependencia circular
    // private let menuBarManager = MenuBarManager.shared
    
    // Atajos configurados (simplificado sin Carbon)
    private struct Shortcut {
        let name: String
        let keyCombination: String
        let action: () -> Void
        
        init(name: String, keyCombination: String, action: @escaping () -> Void) {
            self.name = name
            self.keyCombination = keyCombination
            self.action = action
        }
    }
    
    private let shortcuts: [Shortcut] = [
        Shortcut(name: "Toggle Popover", keyCombination: "⌘⇧P", action: {
            // Acceso directo sin dependencia circular
            MenuBarManager.shared.togglePopover()
        }),
        
        Shortcut(name: "Show Popover", keyCombination: "⌘P", action: {
            MenuBarManager.shared.showPopover()
        }),
        
        Shortcut(name: "Close Popover", keyCombination: "⌘⌥P", action: {
            MenuBarManager.shared.closePopover()
        }),
    ]
    
    private var hotKeyRef: EventHotKeyRef?
    private var promptHotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var promptHotkeyMap: [UInt32: UUID] = [:]
    private var nextHotKeyId: UInt32 = 2
    
    private var localMonitor: Any?
    private var permissionTimer: Timer?
    
    private init() {
        print("✅ ShortcutManager inicializado")
        checkAccessibilityPermissions()
        setupMonitors()
        setupCarbonHotKey()
        startPermissionPolling()
        setupLifecycleObservers()
    }
    
    // MARK: - Sincronización Automática
    
    private func startPermissionPolling() {
        // Solo iniciar polling si aún no tenemos permisos
        guard !isAccessibilityGranted else { return }
        
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Si ya se concedió, detener el timer
            if self.checkAccessibilityPermissions(forceDialog: false) {
                print("✨ Permisos detectados automáticamente. Deteniendo polling.")
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
            }
        }
    }
    
    private func setupLifecycleObservers() {
        // Verificar solo cuando el popover se va a mostrar (vía notificación personalizada o evento)
        // Por ahora mantenemos didBecomeActive pero con control de frecuencia
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkAccessibilityPermissions(forceDialog: false)
        }
    }
    
    // MARK: - Carbon HotKey (Detección Global Real)
    
    func setupCarbonHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        let prefs = PreferencesManager.shared
        guard prefs.globalShortcutEnabled else { return }
        
        let keyCode = UInt32(prefs.hotkeyCode)
        var carbonModifiers: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: UInt(prefs.hotkeyModifiers))
        
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let hotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 1) // 'PROM'
        
        var registration: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &registration)
        
        if status == noErr {
            hotKeyRef = registration
            
            // Instalar el manejador de eventos
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            
            InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                // Extraer el ID del HotKey presionado
                var hkCom: EventHotKeyID = EventHotKeyID()
                let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
                
                if status == noErr {
                    let hotKeyId = hkCom.id
                    ShortcutManager.handleGlobalHotKey(id: hotKeyId)
                }
                
                return noErr
            }, 1, &eventType, nil, nil)
            
            print("💎 Carbon HotKey registrado: \(prefs.hotkeyCode)")
        }
    }
    
    // Método para registrar hotkeys dinámicos de prompts
    func registerPromptHotkeys(prompts: [Prompt]) {
        // Limpiar anteriores
        for (_, ref) in promptHotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        promptHotKeyRefs.removeAll()
        promptHotkeyMap.removeAll()
        nextHotKeyId = 2 // 1 está reservado para Toggle Popover
        
        for prompt in prompts {
            guard let shortcutStr = prompt.customShortcut else { continue }
            let parts = shortcutStr.split(separator: ":")
            guard parts.count == 2,
                  let kc = UInt32(parts[0]),
                  let mods = UInt(parts[1]) else { continue }
            
            var carbonModifiers: UInt32 = 0
            let flags = NSEvent.ModifierFlags(rawValue: mods)
            if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            
            let hotKeyId = nextHotKeyId
            nextHotKeyId += 1
            
            let hotKeyIDStruct = EventHotKeyID(signature: OSType(1347571781), id: hotKeyId)
            var registration: EventHotKeyRef?
            
            let status = RegisterEventHotKey(kc, carbonModifiers, hotKeyIDStruct, GetApplicationEventTarget(), 0, &registration)
            
            if status == noErr, let ref = registration {
                promptHotKeyRefs[hotKeyId] = ref
                promptHotkeyMap[hotKeyId] = prompt.id
                print("💎 Carbon HotKey registrado para prompt: \(prompt.title)")
            }
        }
    }
    
    // Método estático para el handler de Carbon
    static func handleGlobalHotKey(id: UInt32) {
        DispatchQueue.main.async {
            shared.handleCarbonHotKey(id: id)
        }
    }
    
    func handleCarbonHotKey(id: UInt32) {
        if id == 1 {
            print("🚀 Carbon HotKey (Principal) detectado!")
            MenuBarManager.shared.togglePopover()
        } else if let promptId = promptHotkeyMap[id] {
            print("🚀 Carbon HotKey (Prompt) detectado para ID: \(promptId)")
            // Notificar a PromptService para copiar
            NotificationCenter.default.post(name: NSNotification.Name("PromtierCustomShortcutPressed"), object: promptId)
        }
    }
    
    // MARK: - Accesibilidad
    
    private var lastPermissionCheck: Date = Date.distantPast
    
    @discardableResult
    func checkAccessibilityPermissions(forceDialog: Bool = false, ignoreSuppression: Bool = false) -> Bool {
        // Evitar spam al sistema: si no es forzado, solo comprobar cada 60 segundos
        if !forceDialog && Date().timeIntervalSince(lastPermissionCheck) < 60 {
            return isAccessibilityGranted
        }
        
        lastPermissionCheck = Date()
        
        // 1. Comprobación silenciosa para actualizar el estado interno
        let silentOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(silentOptions)
        
        // Actualizar propiedad publicada para la UI
        DispatchQueue.main.async {
            if self.isAccessibilityGranted != isTrusted {
                self.isAccessibilityGranted = isTrusted
            }
        }
        
        print("🔍 [ShortcutManager] Comprobando accesibilidad. Estado: \(isTrusted ? "CONCEDIDO" : "DENEGADO")")
        
        // 2. Si no es confiable y se solicita diálogo (respetando la supresión a menos que se ignore)
        if !isTrusted && forceDialog {
            if !PreferencesManager.shared.suppressAccessibilityWarning || ignoreSuppression {
                print("🏛️ Invocando diálogo de accesibilidad nativo de macOS")
                
                // Esta llamada disparará el diálogo del sistema si el proceso no es confiable
                let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(promptOptions)
            } else {
                print("ℹ️ Aviso de accesibilidad suprimido por el usuario.")
            }
        }
        
        return isTrusted
    }
    
    // MARK: - Monitores de Eventos
    
    private func setupMonitors() {
        // Monitor local (cuando la app está en foco)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isEnabled else { return event }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)
        
        // ⌘K (Búsqueda Rápida)
        if modifiers == .command && keyCode == 40 {
            MenuBarManager.shared.showWithState(.main)
            return nil
        }
        
        // ⌘N (Nuevo Prompt)
        if modifiers == .command && keyCode == 45 {
            MenuBarManager.shared.showWithState(.newPrompt)
            return nil
        }
        
        return event
    }
    
    // MARK: - Control
    
    func enableShortcuts() {
        isEnabled = true
        setupCarbonHotKey()
    }
    
    func disableShortcuts() {
        isEnabled = false
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    func toggleShortcuts() {
        if isEnabled {
            disableShortcuts()
        } else {
            enableShortcuts()
        }
    }
    
    func getShortcutInfo() -> [(name: String, key: String, modifiers: String)] { [] }
}
