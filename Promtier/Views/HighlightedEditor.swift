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
            
            var actualInsert = toInsert
            var shiftFocus = 0
            
            // Asegurar espacio antes si es una variable {{...}}
            if toInsert.hasPrefix("{{") {
                if selectedRange.location > 0 {
                    let prevCharRange = NSRange(location: selectedRange.location - 1, length: 1)
                    let prevChar = nsString.substring(with: prevCharRange)
                    if prevChar != " " && prevChar != "\n" {
                        actualInsert = " " + toInsert
                        shiftFocus = 1
                    }
                }
            }
            
            // Insertar el texto
            textView.insertText(actualInsert, replacementRange: selectedRange)
            
            // Si insertamos una variable {{variable}}, posicionar el cursor adentro
            if toInsert == "{{variable}}" {
                let newLocation = selectedRange.location + 2 + shiftFocus
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
                    // Si ya está activa, intentamos cerrarla enviando cancelOperation al textView específicamente
                    textView.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
                } else {
                    if textView.selectedRange().length == 0 {
                        textView.selectAll(nil)
                    }
                    textView.showWritingTools(nil)
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
    
    // MARK: - Coordinator
    
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
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            applyHighlighting(textView) // Re-aplicar para actualizar el bracket matching
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
            
            // Lógica para saltar fuera de variables {{...}} con TAB o ENTER
            if commandSelector == #selector(NSResponder.insertTab(_:)) ||
                commandSelector == #selector(NSResponder.insertNewline(_:)) ||
                commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                
                if let varRange = isInsideVariable(textView) {
                    let targetLoc = varRange.location + varRange.length
                    textView.setSelectedRange(NSRange(location: targetLoc, length: 0))
                    textView.insertText(" ", replacementRange: NSRange(location: targetLoc, length: 0))
                    return true
                }
            }
            
            return false
        }
        
        // Helper para detectar si estamos dentro de una variable
        private func isInsideVariable(_ textView: NSTextView) -> NSRange? {
            let text = textView.string as NSString
            let sel = textView.selectedRange()
            let lineRange = text.lineRange(for: sel)
            let line = text.substring(with: lineRange) as NSString
            let relLoc = sel.location - lineRange.location
            
            // Buscar hacia atrás el {{
            var startLocInLine = -1
            if relLoc >= 2 {
                for i in (0...(relLoc - 2)).reversed() {
                    if i + 2 <= line.length && line.substring(with: NSRange(location: i, length: 2)) == "{{" {
                        startLocInLine = i
                        break
                    }
                    // Si encontramos }} antes de {{, estamos fuera
                    if i + 2 <= line.length && line.substring(with: NSRange(location: i, length: 2)) == "}}" {
                        break
                    }
                }
            }
            
            if startLocInLine == -1 { return nil }
            
            // Buscar hacia adelante el }}
            var endLocInLine = -1
            if relLoc < line.length {
                for i in relLoc...(line.length - 2) {
                    if line.substring(with: NSRange(location: i, length: 2)) == "}}" {
                        endLocInLine = i + 2
                        break
                    }
                    // Si encontramos otro {{ antes de }}, cancelamos
                    if line.substring(with: NSRange(location: i, length: 2)) == "{{" {
                        break
                    }
                }
            }
            
            if endLocInLine == -1 { return nil }
            
            return NSRange(location: lineRange.location + startLocInLine, length: endLocInLine - startLocInLine)
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Lógica para saltar fuera con ESPACIO
            if replacementString == " " {
                if let varRange = isInsideVariable(textView) {
                    let targetLoc = varRange.location + varRange.length
                    textView.setSelectedRange(NSRange(location: targetLoc, length: 0))
                    textView.insertText(" ", replacementRange: NSRange(location: targetLoc, length: 0))
                    return false
                }
            }
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
                
                let cursorLocation = textView.selectedRange().location
                
                // Ejecutar regex en segundo plano para no bloquear el hilo principal
                DispatchQueue.global(qos: .userInteractive).async {
                    // 1. Regex para variables {{...}}
                    let varPattern = "\\{\\{([^}]+)\\}\\}"
                    let varRegex = try? NSRegularExpression(pattern: varPattern, options: [])
                    let varMatches = varRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    
                    // 2. Regex para Brackets/Llaves individuales
                    let bracketPattern = "[\\{\\}\\[\\]\\(\\)]"
                    let bracketRegex = try? NSRegularExpression(pattern: bracketPattern, options: [])
                    let bracketMatches = bracketRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    
                    // 3. Encontrar pareja de brackets si el cursor está en uno
                    var matchingBracketRange: NSRange? = nil
                    var currentBracketRange: NSRange? = nil
                    
                    if cursorLocation > 0 && cursorLocation <= text.count {
                        let charRange = NSRange(location: cursorLocation - 1, length: 1)
                        let char = (text as NSString).substring(with: charRange)
                        if "{}[]()".contains(char) {
                            currentBracketRange = charRange
                            if let partner = self.findMatchingBracket(in: text, for: char, at: cursorLocation - 1) {
                                matchingBracketRange = NSRange(location: partner, length: 1)
                            }
                        }
                    }
                    
                    // Aplicar cambios en el hilo principal
                    DispatchQueue.main.async {
                        // VALIDACIÓN CRÍTICA: Si el texto cambió mientras calculábamos, abortar para evitar crash
                        let currentLength = textStorage.length
                        if currentLength == 0 { return }
                        
                        textStorage.beginEditing()
                        
                        // Resetear estilos base
                        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
                        textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: self.parent.fontSize), range: fullRange)
                        textStorage.removeAttribute(.backgroundColor, range: fullRange)
                        textStorage.removeAttribute(.underlineStyle, range: fullRange)
                        
                        // Función helper interna para aplicar atributos de forma segura
                        func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
                            if range.location + range.length <= textStorage.length {
                                textStorage.addAttribute(name, value: value, range: range)
                            }
                        }
                        
                        // Aplicar resaltado de brackets individuales
                        for match in bracketMatches {
                            safeAddAttribute(.foregroundColor, value: NSColor.systemOrange.withAlphaComponent(0.8), range: match.range)
                        }
                        
                        // Aplicar resaltado de variables {{...}}
                        for match in varMatches {
                            let range = match.range
                            safeAddAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                            safeAddAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.08), range: range)
                            safeAddAttribute(.font, value: NSFont.systemFont(ofSize: self.parent.fontSize, weight: .bold), range: range)
                        }
                        
                        // Aplicar resaltado de Bracket Matching (VS Code style)
                        if let current = currentBracketRange {
                            safeAddAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.3), range: current)
                            safeAddAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: current)
                        }
                        if let matching = matchingBracketRange {
                            safeAddAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.3), range: matching)
                            safeAddAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matching)
                        }
                        
                        textStorage.endEditing()
                    }
                }
            }
        }
        
        /// Algoritmo para encontrar el bracket correspondiente
        private func findMatchingBracket(in text: String, for bracket: String, at location: Int) -> Int? {
            let nsText = text as NSString
            let pairs: [String: String] = ["{": "}", "}": "{", "[": "]", "]": "[", "(": ")", ")": "("]
            guard let target = pairs[bracket] else { return nil }
            
            let isOpen = "{[(".contains(bracket)
            var stack = 0
            
            if isOpen {
                for i in (location + 1)..<nsText.length {
                    let char = nsText.substring(with: NSRange(location: i, length: 1))
                    if char == bracket { stack += 1 }
                    else if char == target {
                        if stack == 0 { return i }
                        stack -= 1
                    }
                }
            } else {
                for i in (0..<location).reversed() {
                    let char = nsText.substring(with: NSRange(location: i, length: 1))
                    if char == bracket { stack += 1 }
                    else if char == target {
                        if stack == 0 { return i }
                        stack -= 1
                    }
                }
            }
            return nil
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
