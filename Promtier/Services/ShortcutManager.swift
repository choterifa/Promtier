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
    
    private init() {
        print("✅ ShortcutManager inicializado")
        checkAccessibilityPermissions()
        setupMonitors()
        setupCarbonHotKey()
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
    
    func checkAccessibilityPermissions(forceDialog: Bool = false) {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isTrusted && forceDialog {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Acceso de Accesibilidad Requerido"
                alert.informativeText = "Para que los atajos funcionen mejor, por favor activa Promtier en los Ajustes de Accesibilidad.\n\nAl pulsar 'Entendido', se abrirá la configuración por ti."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Entendido")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    if let url = url {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
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
