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
    
    private init() {
        print("✅ ShortcutManager inicializado")
        print("📋 Atajos disponibles:")
        for shortcut in shortcuts {
            print("   \(shortcut.keyCombination) - \(shortcut.name)")
        }
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
