//
//  HighlightedEditor.swift
//  Promtier
//
//  COMPONENTE: Editor de texto nativo con resaltado de variables y auto-indentado
//

import SwiftUI
import AppKit

struct HighlightedEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var triggerAppleIntelligence: Bool
    @Binding var isAIActive: Bool
    var fontSize: CGFloat
    
    // Autocompletado (Snippets)
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    var isPremium: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true 
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = false // Siempre visible
        
        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        
        // Configuraciones de comportamiento para Prompts (evitar cambios automáticos molestos)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = true
        
        // Activar Apple Intelligence Writing Tools (macOS 15.0+)
        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .complete
        }
        
        // Optimizar para scrolling suave
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Sincronizar texto si cambió externamente
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting(textView)
        }
        
        // Manejar petición de inserción
        if let toInsert = insertionRequest {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            
            // Insertar el texto
            textView.insertText(toInsert, replacementRange: selectedRange)
            
            // Si insertamos una variable {{variable}}, posicionar el cursor adentro
            if toInsert == "{{variable}}" {
                let newLocation = selectedRange.location + 2 // Mover 2 posiciones (después de {{)
                let newRange = NSRange(location: newLocation, length: 8) // Seleccionar "variable"
                textView.setSelectedRange(newRange)
            }
            
            // Actualizar el binding padre inmediatamente
            DispatchQueue.main.async {
                self.text = textView.string
                self.insertionRequest = nil
            }
        }
        
        // Manejar petición de reemplazar snippet
        if let snippetText = replaceSnippetRequest {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            
            // Buscar la última "/" antes del cursor
            let textBeforeCursor = nsString.substring(to: selectedRange.location)
            if let lastSlashIndex = textBeforeCursor.lastIndex(of: "/") {
                let distance = textBeforeCursor.distance(from: textBeforeCursor.startIndex, to: lastSlashIndex)
                let replacementRange = NSRange(location: distance, length: selectedRange.location - distance)
                
                textView.insertText(snippetText, replacementRange: replacementRange)
            } else {
                textView.insertText(snippetText, replacementRange: selectedRange) // fallback
            }
            
            DispatchQueue.main.async {
                self.text = textView.string
                self.replaceSnippetRequest = nil
                self.showSnippets = false
            }
        }
        
        // Manejar petición de Inteligencia de Apple
        if triggerAppleIntelligence {
            if #available(macOS 15.0, *) {
                if isAIActive {
                    // Simular ESC para cerrar herramientas de IA
                    NSApp.sendAction(#selector(NSResponder.cancelOperation(_:)), to: nil, from: nil)
                    self.isAIActive = false
                } else {
                    if textView.selectedRange().length == 0 {
                        textView.selectAll(nil)
                    }
                    textView.showWritingTools(nil)
                    // Fallback inmediato
                    self.isAIActive = true
                }
            }
            
            DispatchQueue.main.async {
                self.triggerAppleIntelligence = false
            }
        }
        
        // Actualizar fuente si cambió
        if textView.font?.pointSize != fontSize {
            textView.font = .systemFont(ofSize: fontSize)
            context.coordinator.applyHighlighting(textView)
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedEditor
        
        init(_ parent: HighlightedEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            applyHighlighting(textView)
            
            // Actualizar búsqueda de snippets si está activo
            if self.parent.showSnippets {
                let text = textView.string
                let selectedRange = textView.selectedRange()
                let index = text.index(text.startIndex, offsetBy: selectedRange.location)
                let textBeforeCursor = text[..<index]
                
                if let lastSlashIndex = textBeforeCursor.lastIndex(of: "/") {
                    let query = textBeforeCursor[text.index(after: lastSlashIndex)...]
                    if !query.contains(" ") && !query.contains("\n") {
                        self.parent.snippetSearchQuery = String(query)
                    } else {
                        self.parent.showSnippets = false
                    }
                } else {
                    self.parent.showSnippets = false
                }
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if self.parent.showSnippets {
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    DispatchQueue.main.async {
                        self.parent.snippetSelectedIndex = max(0, self.parent.snippetSelectedIndex - 1)
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    DispatchQueue.main.async {
                        self.parent.snippetSelectedIndex += 1
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                    DispatchQueue.main.async {
                        self.parent.triggerSnippetSelection = true
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) { // ESC
                    DispatchQueue.main.async {
                        self.parent.showSnippets = false
                    }
                    return true
                }
            }
            return false
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if replacementString == "/" && self.parent.isPremium {
                DispatchQueue.main.async {
                    self.parent.showSnippets = true
                    self.parent.snippetSearchQuery = ""
                }
            }
            
            if replacementString == "\n" {
                if self.parent.showSnippets {
                    DispatchQueue.main.async { self.parent.showSnippets = false }
                }
                
                // Lógica de Auto-indentado y listas
                let content = textView.string as NSString
                let lineRange = content.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
                let line = content.substring(with: lineRange)
                
                // Detectar indentación
                var indentation = ""
                for char in line {
                    if char == " " || char == "\t" {
                        indentation.append(char)
                    } else {
                        break
                    }
                }
                
                // Detectar si es una lista (- , * , 1. )
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                var listMarker = ""
                if trimmedLine.hasPrefix("- ") { listMarker = "- " }
                else if trimmedLine.hasPrefix("* ") { listMarker = "* " }
                else if trimmedLine.hasPrefix("• ") { listMarker = "• " }
                
                if !indentation.isEmpty || !listMarker.isEmpty {
                    let newString = "\n" + indentation + listMarker
                    textView.insertText(newString, replacementRange: affectedCharRange)
                    return false
                }
            }
            return true
        }
        
        // Timer para debounce del resaltado
        private var highlightTimer: Timer?
        
        func applyHighlighting(_ textView: NSTextView) {
            highlightTimer?.invalidate()
            
            // Debounce de 150ms para evitar lag al escribir rápido
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self, let textStorage = textView.textStorage else { return }
                
                let text = textView.string
                let fullRange = NSRange(location: 0, length: textStorage.length)
                if fullRange.length == 0 { return }
                
                // Ejecutar regex en segundo plano para no bloquear el hilo principal
                DispatchQueue.global(qos: .userInteractive).async {
                    let pattern = "\\{\\{([^}]+)\\}\\}"
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
                    let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                    
                    // Aplicar cambios en el hilo principal
                    DispatchQueue.main.async {
                        // Solo resetear si hay texto
                        textStorage.beginEditing()
                        
                        // Resetear estilos base eficientemente (solo si es necesario o por tramos)
                        // Para optimizar, podríamos solo resetear los rangos que tenían highlight antes
                        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
                        textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: self.parent.fontSize), range: fullRange)
                        textStorage.removeAttribute(.backgroundColor, range: fullRange)
                        
                        for match in matches {
                            let range = match.range
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                            textStorage.addAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.08), range: range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: self.parent.fontSize, weight: .bold), range: range)
                        }
                        
                        textStorage.endEditing()
                    }
                }
            }
        }
        
        // MARK: - Writing Tools (macOS 15+)
        
        // Usamos Any para que compile en versiones anteriores del SDK, pero selectors de macOS 15
        @objc(textView:writingToolsWillBeginSession:)
        func writingToolsWillBegin(_ textView: NSTextView, session: Any) {
            DispatchQueue.main.async {
                self.parent.isAIActive = true
            }
        }
        
        @objc(textView:writingToolsDidEndSession:)
        func writingToolsDidEnd(_ textView: NSTextView, session: Any) {
            DispatchQueue.main.async {
                self.parent.isAIActive = false
            }
        }
        
        // Variante alternativa de selector
        @objc(textView:writingToolsWillBegin:)
        func writingToolsWillBeginAlt(_ textView: NSTextView, session: Any) {
            DispatchQueue.main.async {
                self.parent.isAIActive = true
            }
        }



    }
}
