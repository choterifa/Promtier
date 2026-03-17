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
        // Asegurar que el popover se cierre para devolver el foco a la aplicación anterior
        DispatchQueue.main.async {
            if MenuBarManager.shared.isPopoverShown {
                MenuBarManager.shared.closePopover()
            }
            
            // Esperar a que el foco regrese a la app anterior (0.3s suele ser suficiente)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let source = CGEventSource(stateID: .combinedSessionState)
                
                // Definir códigos de tecla para Cmd y V
                let vCode: CGKeyCode = 9 // Código para 'V' en Mac
                
                // 1. Command Down
                let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                cmdDown?.flags = .maskCommand
                
                // 2. V Down
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true)
                vDown?.flags = .maskCommand
                
                // 3. V Up
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false)
                vUp?.flags = .maskCommand
                
                // 4. Command Up
                let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                cmdUp?.flags = []
                
                // Ejecutar secuencia
                cmdDown?.post(tap: .cghidEventTap)
                vDown?.post(tap: .cghidEventTap)
                vUp?.post(tap: .cghidEventTap)
                cmdUp?.post(tap: .cghidEventTap)
                
                print("✅ Auto-Paste (CGEvent) ejecutado")
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
