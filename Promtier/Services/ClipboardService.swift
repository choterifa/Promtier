//
//  ClipboardService.swift
//  Promtier
//
//  SERVICIO: Manejo del clipboard del sistema
//  Created by Carlos on 15/03/26.
//

import Foundation
import AppKit
import Combine

// SERVICIO: Copiar al clipboard con historial opcional
class ClipboardService: ObservableObject {
    static let shared = ClipboardService()
    
    // CONFIGURABLE: Historial de clipboard (cantidad máxima)
    private let maxHistoryCount = 10
    
    @Published var history: [String] = []
    
    private init() {}
    
    // MARK: - Métodos principales
    
    /// Copia texto al clipboard del sistema
    func copyToClipboard(_ text: String, addToHistory: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Agregar al historial si está habilitado
        if addToHistory {
            self.addToHistory(text)
        }
        
        // CONFIGURABLE: Notificación visual (opcional)
        showCopyNotification()
        
        // AUTO-PASTE: Magia de pegado si está habilitada
        if PreferencesManager.shared.autoPaste {
            performAutoPaste()
        }
    }
    
    /// Ejecuta el pegado automático mediante CoreGraphics (Simulación de Teclado)
    private func performAutoPaste() {
        // Asegurar que el proceso tiene permisos antes de intentar
        guard ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: false) else {
            print("⚠️ Auto-Paste cancelado: Sin permisos de accesibilidad")
            return
        }
        
        // 1. Forzar que la aplicación se oculte para devolver el foco de forma inmediata y fiable
        DispatchQueue.main.async {
            if MenuBarManager.shared.isPopoverShown {
                MenuBarManager.shared.closePopover()
            }
            
            // Ocultar la app asegura que macOS devuelva el foco a la aplicación anterior al 100%
            NSApp.hide(nil)
            
            // 2. Esperar un margen de seguridad (0.5s) para que la transición de foco se complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Usar .hidSystemState para ignorar estados de teclas de la sesión actual y ser más fiel al hardware
                let source = CGEventSource(stateID: .hidSystemState)
                
                // Definir códigos de tecla nativos (Virtual Key Codes de Carbon)
                let kVK_Command: CGKeyCode = 55
                let kVK_ANSI_V: CGKeyCode = 9
                
                // Crear eventos
                let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: true)
                vDown?.flags = .maskCommand
                
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: false)
                vUp?.flags = .maskCommand
                
                let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)
                
                // Ejecutar secuencia con micro-retrasos
                cmdDown?.post(tap: .cghidEventTap)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    vDown?.post(tap: .cghidEventTap)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        vUp?.post(tap: .cghidEventTap)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            cmdUp?.post(tap: .cghidEventTap)
                            print("✅ Auto-Paste (Robust CGEvent) ejecutado satisfactoriamente")
                        }
                    }
                }
            }
        }
    }
    
    /// Obtiene el contenido actual del clipboard
    func getClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    // MARK: - Historial
    
    /// Agrega texto al historial con límite configurable
    private func addToHistory(_ text: String) {
        // Evitar duplicados consecutivos
        if history.first == text {
            return
        }
        
        history.insert(text, at: 0)
        
        // Mantener límite del historial
        if history.count > maxHistoryCount {
            history.removeLast()
        }
    }
    
    /// Limpia el historial completo
    func clearHistory() {
        history.removeAll()
    }
    
    /// Copia un item específico del historial
    func copyFromHistory(_ index: Int) {
        guard index >= 0 && index < history.count else { return }
        copyToClipboard(history[index], addToHistory: false)
    }
    
    // MARK: - Notificaciones
    
    /// Muestra notificación visual de copia exitosa
    private func showCopyNotification() {
        // CONFIGURABLE: Usar print para notificación simple (evita deprecated APIs)
        print("📋 Prompt copiado al clipboard")
        
        // CONFIGURABLE: Alternativa futura con UserNotifications framework
        // Por ahora, usamos notificación simple para compatibilidad
    }
    
    // MARK: - Utilidades
    
    /// Verifica si el clipboard contiene texto
    func hasTextContent() -> Bool {
        return getClipboardContent() != nil
    }
    
    /// Obtiene longitud del contenido actual
    func getContentLength() -> Int {
        return getClipboardContent()?.count ?? 0
    }
}
