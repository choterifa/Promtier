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
        // Reducido a 2.5s para ahorrar muchisima batería (App Nap friendly)
        monitorTimer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPasteboard()
            }
        
        // Comprobar forzosamente cada vez que la app pase a primer plano
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
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
    
    /// Obtiene el contenido actual del clipboard, con sanitización de seguridad
    func getClipboardContent() -> String? {
        guard let content = NSPasteboard.general.string(forType: .string) else { return nil }
        
        // 🛡️ Seguridad/Auditoría: Validar y truncar para evitar desbordes de memoria o caídas (Ej: más de 500,000 caracteres)
        let maxLimit = 500_000
        if content.count > maxLimit {
            return String(content.prefix(maxLimit))
        }
        
        return content
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
    }
}
