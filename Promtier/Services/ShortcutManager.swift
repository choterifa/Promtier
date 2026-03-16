//
//  ShortcutManager.swift
//  Promtier
//
//  SERVICIO: Gestión de atajos de teclado globales (simplificado)
//  Created by Carlos on 15/03/26.
//

import AppKit
import Combine

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
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    private init() {
        print("✅ ShortcutManager inicializado")
        checkAccessibilityPermissions()
        setupMonitors()
    }
    
    // MARK: - Accesibilidad
    
    func checkAccessibilityPermissions(forceDialog: Bool = false) {
        // Al pasar 'false', evitamos que macOS muestre su ventana negra nativa
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isTrusted {
            print("⚠️ Permisos de accesibilidad no concedidos.")
            
            if forceDialog {
                DispatchQueue.main.async {
                    // 1. Mostrar primero nuestra alerta informativa
                    let alert = NSAlert()
                    alert.messageText = "Acceso de Accesibilidad Requerido"
                    alert.informativeText = "Para que los atajos globales funcionen, por favor activa Promtier en los Ajustes de Accesibilidad.\n\nAl pulsar 'Entendido', se abrirá la configuración por ti."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Entendido")
                    
                    // 2. Si el usuario da a "Entendido", abrir los ajustes
                    if alert.runModal() == .alertFirstButtonReturn {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                        if let url = url {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        } else {
            print("✅ Aplicación con permisos de accesibilidad.")
        }
    }
    
    // MARK: - Monitores de Eventos
    
    private func setupMonitors() {
        // Monitor local (cuando la app está en foco)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
        
        // Monitor global (cuando la app NO está en foco)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isEnabled && PreferencesManager.shared.globalShortcutEnabled else { return event }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)
        
        let prefs = PreferencesManager.shared
        
        // Atajo personalizado para Toggle Popover
        if modifiers.rawValue == UInt(prefs.hotkeyModifiers) && keyCode == prefs.hotkeyCode {
            print("🚀 Atajo global detectado: Toggle Popover")
            DispatchQueue.main.async {
                MenuBarManager.shared.togglePopover()
            }
            return nil
        }
        
        // ⌘K (Búsqueda Rápida) - KeyCode 40 es 'K'
        if modifiers == .command && keyCode == 40 {
            MenuBarManager.shared.showWithState(.main)
            return nil
        }
        
        // ⌘N (Nuevo Prompt) - KeyCode 45 es 'N'
        if modifiers == .command && keyCode == 45 {
            MenuBarManager.shared.showWithState(.newPrompt)
            return nil
        }
        
        return event
    }
    
    // MARK: - Control
    
    func enableShortcuts() {
        isEnabled = true
        print("✅ Atajos habilitados")
    }
    
    func disableShortcuts() {
        isEnabled = false
        print("⚠️ Atajos deshabilitados")
    }
    
    func toggleShortcuts() {
        if isEnabled {
            disableShortcuts()
        } else {
            enableShortcuts()
        }
    }
    
    // MARK: - Información
    
    func getShortcutInfo() -> [(name: String, key: String, modifiers: String)] {
        return shortcuts.map { shortcut in
            return (name: shortcut.name, key: shortcut.keyCombination, modifiers: "")
        }
    }
}
