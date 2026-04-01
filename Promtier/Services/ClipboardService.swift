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
    
    // CONTEXTO: Rastrear el origen del contenido del portapapeles
    @Published var lastSourceAppBundleID: String?
    private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount
    private var monitorTimer: AnyCancellable?
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitorTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPasteboard()
            }
    }
    
    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount
        
        // PROTECCION PRIVACIDAD: Ignorar portapapeles velados (como 1Password o Llavero de iCloud)
        if let types = pasteboard.types {
            if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) ||
               types.contains(NSPasteboard.PasteboardType("com.agilebits.onepassword")) {
                self.lastSourceAppBundleID = nil
                return
            }
        }
        
        // Si el cambio ocurrió mientras otra app era la activa, registrar su bundleID
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.lastSourceAppBundleID = frontmostApp.bundleIdentifier
        }
    }
    
    // MARK: - Métodos principales
    
    /// Copia texto al clipboard del sistema
    func copyToClipboard(_ text: String, addToHistory: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        finalizeCopy(plainText: text, addToHistory: addToHistory)
    }

    /// Copia rich text al clipboard conservando un fallback de texto plano
    func copyRichTextToClipboard(_ attributedText: NSAttributedString, addToHistory: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let fullRange = NSRange(location: 0, length: attributedText.length)
        if let rtfData = try? attributedText.data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        pasteboard.setString(attributedText.string, forType: .string)

        finalizeCopy(plainText: attributedText.string, addToHistory: addToHistory)
    }
    
    /// Ejecuta el pegado automático mediante CoreGraphics (Simulación de Teclado)
    private func performAutoPaste() {
        // Asegurar que el proceso tiene permisos antes de intentar
        guard ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: false) else {
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
        // Mantener silencioso para no ensuciar la consola; el feedback visual/sonoro
        // vive en la UI y los haptics.
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

    private func finalizeCopy(plainText: String, addToHistory: Bool) {
        if addToHistory {
            self.addToHistory(plainText)
        }

        showCopyNotification()

        if PreferencesManager.shared.autoPaste {
            performAutoPaste()
        }
    }
}
