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
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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
        // También verificar cuando la app vuelve al primer plano
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkAccessibilityPermissions(forceDialog: false)
            // Reiniciar polling si sigue sin permisos
            self?.startPermissionPolling()
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
                // Llamada estática para evitar captura de contexto
                ShortcutManager.handleGlobalHotKey()
                return noErr
            }, 1, &eventType, nil, nil)
            
            print("💎 Carbon HotKey registrado: \(prefs.hotkeyCode)")
        }
    }
    
    // Método estático para el handler de Carbon
    static func handleGlobalHotKey() {
        DispatchQueue.main.async {
            shared.handleCarbonHotKey()
        }
    }
    
    func handleCarbonHotKey() {
        print("🚀 Carbon HotKey detectado!")
        MenuBarManager.shared.togglePopover()
    }
    
    // MARK: - Accesibilidad
    
    @discardableResult
    func checkAccessibilityPermissions(forceDialog: Bool = false, ignoreSuppression: Bool = false) -> Bool {
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
