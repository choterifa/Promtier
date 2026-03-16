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
    
    /// Ejecuta el pegado automático mediante AppleScript
    private func performAutoPaste() {
        // CONFIGURABLE: Retraso sutil para dejar que la otra app tome foco si es necesario
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let scriptSource = "tell application \"System Events\" to keystroke \"v\" using {command down}"
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let err = error {
                    print("Error en Auto-Paste: \(err)")
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
