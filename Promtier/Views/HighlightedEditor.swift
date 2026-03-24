//
//  HighlightedEditor.swift
//  Promtier
//
//  COMPONENTE: Editor de texto nativo con resaltado de variables y auto-indentado
//

import SwiftUI
import AppKit

class PassThroughScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        guard let textView = documentView as? NSTextView else {
            super.scrollWheel(with: event)
            return
        }
        
        if textView.window?.firstResponder == textView {
            super.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

class PromtierTextView: NSTextView {
    var isCurrentLineHighlightingEnabled: Bool = true
    var currentLineHighlightColor: NSColor = .controlAccentColor
    
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        
        guard isCurrentLineHighlightingEnabled,
              let layoutManager = layoutManager,
              let textContainer = textContainer,
              let window = window,
              window.firstResponder == self,
              selectedRange().length == 0 else { return }
        
        let range = selectedRange()
        // Safety check for empty text or range at the end
        let glyphIndex = min(range.location, layoutManager.numberOfGlyphs > 0 ? layoutManager.numberOfGlyphs - 1 : 0)
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        
        let highlightRect = NSRect(
            x: 0,
            y: rect.origin.y + textContainerInset.height,
            width: bounds.width,
            height: rect.height
        )
        
        // Fill background with slightly higher opacity
        currentLineHighlightColor.withAlphaComponent(0.1).set()
        highlightRect.fill()
        
        // Add a subtle left border for extra visibility (Xcode style)
        let borderRect = NSRect(x: 0, y: highlightRect.origin.y, width: 4, height: highlightRect.height)
        currentLineHighlightColor.withAlphaComponent(0.5).set()
        borderRect.fill()
    }
}

struct HighlightedEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var triggerAIRequest: String?
    @Binding var isAIActive: Bool
    let editorID: String
    @Binding var isFocused: Bool
    var focusRequest: Binding<Bool>? = nil
    @Binding var selectedRange: NSRange?
    @Binding var aiResult: AIResult?
    var fontSize: CGFloat
    var themeColor: NSColor = .systemOrange // Color por defecto si no se provee
    
    // Autocompletado (Snippets)
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    
    // Autocompletado (Variables)
    @Binding var showVariables: Bool
    @Binding var variablesSelectedIndex: Int
    @Binding var triggerVariablesSelection: Bool
    
    var isPremium: Bool
    var isHaloEffectEnabled: Bool = true
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PassThroughScrollView()
        scrollView.hasVerticalScroller = true 
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = false // Siempre visible
        
        let textView = PromtierTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.currentLineHighlightColor = themeColor
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        
        // Smart behavior settings
        textView.isAutomaticQuoteSubstitutionEnabled = false
        
        // Optimizar para scrolling suave y performance
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Optimización de renderizado para evitar parpadeos
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        scrollView.documentView = textView
        
        // Listen for Apple Intelligence trigger notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TriggerAppleIntelligence"), object: nil, queue: .main) { _ in
            if textView.window?.firstResponder == textView {
                textView.showWritingTools(nil)
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PromtierTextView else { return }
        
        // Update highlight color
        if textView.currentLineHighlightColor != themeColor {
            textView.currentLineHighlightColor = themeColor
        }
        
        // Sincronizar texto si cambió externamente (sin romper el Undo)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            
            // Usar textStorage para que el cambio sea atómico
            textView.textStorage?.beginEditing()
            textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: textView.string.count), with: text)
            textView.textStorage?.endEditing()
            
            // Restaurar selección de forma segura
            let maxLen = text.count
            let safeRanges = selectedRanges.compactMap { val -> NSValue? in
                let r = val.rangeValue
                return (r.location + r.length <= maxLen) ? val : nil
            }
            
            if !safeRanges.isEmpty {
                textView.selectedRanges = safeRanges
            } else {
                textView.setSelectedRange(NSRange(location: maxLen, length: 0))
            }
            
            context.coordinator.applyHighlighting(textView)
        }
        
        // Aplicar resultados de IA con soporte para Undo
        if let result = aiResult {
            DispatchQueue.main.async {
                applyAIResult(result, to: textView)
                self.aiResult = nil 
            }
        }
        
        // Manejar petición de inserción
        if let toInsert = insertionRequest {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            
            // PREVENCIÓN DE ANIDAMIENTO ROBUSTA: Si ya estamos dentro de un bloque {{...}}
            if toInsert.hasPrefix("{{") {
                let text = textView.string as NSString
                let sel = textView.selectedRange()
                let lineRange = text.lineRange(for: sel)
                let line = text.substring(with: lineRange) as NSString
                let relLoc = sel.location - lineRange.location
                
                // 1. Buscar hacia atrás el {{ en la misma línea
                var foundStart = false
                if relLoc >= 2 {
                    for i in (0...(relLoc - 2)).reversed() {
                        let sub = line.substring(with: NSRange(location: i, length: 2))
                        if sub == "{{" {
                            foundStart = true
                            break
                        }
                        if sub == "}}" { break } // Cierre previo, estamos fuera
                    }
                }
                
                if foundStart {
                    // 2. Buscar hacia adelante el }} en la misma línea
                    var foundEnd = false
                    let checkEndFrom = relLoc + sel.length
                    if checkEndFrom <= line.length - 2 {
                        for i in checkEndFrom...(line.length - 2) {
                            let sub = line.substring(with: NSRange(location: i, length: 2))
                            if sub == "}}" {
                                foundEnd = true
                                break
                            }
                            if sub == "{{" { break } // Nueva apertura antes de cierre, algo raro
                        }
                    }
                    
                    if foundEnd {
                        // YA ESTAMOS DENTRO DE UNA VARIABLE, cancelar inserción para evitar anidamiento
                        DispatchQueue.main.async { self.insertionRequest = nil }
                        return
                    }
                }
            }
            
            var actualInsert = toInsert
            var shiftFocus = 0
            
            // Asegurar espacio antes si es una variable {{...}}
            if toInsert.hasPrefix("{{") {
                if selectedRange.location > 0 && selectedRange.length == 0 { // Solo si es inserción en punto, no reemplazo
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
            
            // Si insertamos una variable, posicionar el cursor adentro seleccionando el nombre
            if toInsert == "{{variable}}" {
                let newLocation = selectedRange.location + 2 + shiftFocus
                let newRange = NSRange(location: newLocation, length: 8) // Seleccionar "variable"
                textView.setSelectedRange(newRange)
            } else if toInsert == "{{area:variable}}" {
                let newLocation = selectedRange.location + 7 + shiftFocus // "{{area:" es 7
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
        
        // triggerAIRequest is now handled by the parent view for Ollama integration
        
        // Actualizar fuente si cambió
        if textView.font?.pointSize != fontSize {
            textView.font = .systemFont(ofSize: fontSize)
            context.coordinator.applyHighlighting(textView)
        }
        
        // Manejar petición de foco
        if let focusRequest = focusRequest, focusRequest.wrappedValue {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                focusRequest.wrappedValue = false
            }
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
            self.parent.selectedRange = textView.selectedRange()
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
            textView.needsDisplay = true // Redibujar para el resaltado de línea actual
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            DispatchQueue.main.async {
                self.parent.isFocused = true
                textView.needsDisplay = true // Redibujar para mostrar resaltado de línea
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            DispatchQueue.main.async {
                self.parent.isFocused = false
                textView.needsDisplay = true // Redibujar para ocultar resaltado de línea
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if self.parent.showVariables {
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    DispatchQueue.main.async {
                        self.parent.variablesSelectedIndex = max(0, self.parent.variablesSelectedIndex - 1)
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    DispatchQueue.main.async {
                        self.parent.variablesSelectedIndex += 1
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                    DispatchQueue.main.async {
                        self.parent.triggerVariablesSelection = true
                    }
                    return true
                } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) { // ESC
                    DispatchQueue.main.async {
                        self.parent.showVariables = false
                    }
                    return true
                }
            }
            
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
        
        // MARK: - Highlighting Logic (Optimized)
        
        private static let varRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])
        private static let bracketRegex = try? NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
        private static let chainRegex = try? NSRegularExpression(pattern: "\\[\\[@Prompt:([^\\]]+)\\]\\]", options: [])
        
        // Markdown Regexes
        private static let mdHeaderRegex = try? NSRegularExpression(pattern: "^#{1,6}\\s+.*$", options: [.anchorsMatchLines])
        private static let mdBoldRegex = try? NSRegularExpression(pattern: "\\*\\*([^\\*]+)\\*\\*|__([^\\_]+)__", options: [])
        private static let mdItalicRegex = try? NSRegularExpression(pattern: "\\*([^\\*\\s][^\\*]*[^\\*\\s])\\*|_([^\\_\\s][^\\_]*[^\\_\\s])_", options: [])
        private static let mdCodeRegex = try? NSRegularExpression(pattern: "`([^`]+)`|```[\\s\\S]*?```", options: [])
        private static let mdLinkRegex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", options: [])
        private static let mdListRegex = try? NSRegularExpression(pattern: "^\\s*([-*+]|\\d+\\.)\\s+", options: [.anchorsMatchLines])

        func applyHighlighting(_ textView: NSTextView) {
            highlightTimer?.invalidate()
            
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: false) { [weak self, weak textView] _ in
                guard let self = self, let textView = textView else { return }
                
                let text = textView.string
                let cursorLocation = textView.selectedRange().location
                let fontSize = self.parent.fontSize
                
                if text.isEmpty { return }
                
                DispatchQueue.global(qos: .userInteractive).async { [weak self, weak textView] in
                    guard let self = self, let textView = textView else { return }
                    
                    let varMatches = Self.varRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let bracketMatches = Self.bracketRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let chainMatches = Self.chainRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    
                    // Markdown matches
                    let headerMatches = Self.mdHeaderRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let boldMatches = Self.mdBoldRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let italicMatches = Self.mdItalicRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let codeMatches = Self.mdCodeRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let linkMatches = Self.mdLinkRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    let listMatches = Self.mdListRegex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
                    
                    var matchingBracketRange: NSRange? = nil
                    var currentBracketRange: NSRange? = nil
                    let nsText = text as NSString
                    
                    let positionsToCheck = [cursorLocation - 1, cursorLocation].filter { $0 >= 0 && $0 < nsText.length }
                    
                    for pos in positionsToCheck {
                        let charRange = NSRange(location: pos, length: 1)
                        let char = nsText.substring(with: charRange)
                        if "{}[]()".contains(char) {
                            if let partner = self.findMatchingBracket(in: text, for: char, at: pos) {
                                currentBracketRange = charRange
                                matchingBracketRange = NSRange(location: partner, length: 1)
                                break
                            }
                        }
                    }
                    
                    DispatchQueue.main.async { [weak textView] in
                        guard let textView = textView, let textStorage = textView.textStorage else { return }
                        if textStorage.string != text { return } // Abortar si el texto cambió
                        
                        let fullRange = NSRange(location: 0, length: textStorage.length)
                        let baseFont = NSFont.systemFont(ofSize: fontSize)
                        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        let codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
                        
                        textStorage.beginEditing()
                        
                        // 1. Reset base attributes (Base Pass)
                        let baseAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.labelColor,
                            .font: baseFont
                        ]
                        textStorage.setAttributes(baseAttributes, range: fullRange)
                        
                        // 2. Markdown Pass (Low priority)
                        for match in headerMatches {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize + 2, weight: .bold), range: match.range)
                        }
                        
                        for match in boldMatches {
                            textStorage.addAttribute(.font, value: boldFont, range: match.range)
                        }
                        
                        for match in italicMatches {
                            textStorage.addAttribute(.font, value: italicFont, range: match.range)
                        }
                        
                        for match in codeMatches {
                            textStorage.addAttribute(.font, value: codeFont, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: NSColor.secondaryLabelColor.withAlphaComponent(0.1), range: match.range)
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
                        }
                        
                        for match in linkMatches {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: match.range)
                            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                        }
                        
                        for match in listMatches {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
                        }

                        // 3. Syntax Highlighting Pass (High priority, overrides Markdown)
                        for match in bracketMatches {
                            textStorage.addAttribute(.foregroundColor, value: self.parent.themeColor, range: match.range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize, weight: .bold), range: match.range)
                        }
                        
                        for match in varMatches {
                            let varColor = self.parent.isHaloEffectEnabled ? NSColor.systemBlue : self.parent.themeColor
                            textStorage.addAttribute(.foregroundColor, value: varColor, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: varColor.withAlphaComponent(0.08), range: match.range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize, weight: .bold), range: match.range)
                        }
                        
                        for match in chainMatches {
                            textStorage.addAttribute(.foregroundColor, value: self.parent.themeColor, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: self.parent.themeColor.withAlphaComponent(0.05), range: match.range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize, weight: .bold), range: match.range)
                            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                        }
                        
                        textStorage.endEditing()
                        
                        // 3. Bracket Matching Pass (ULTRA FAST: Usando Temporary Attributes)
                        // Esto no afecta al Undo ni al almacenamiento de texto.
                        let layoutManager = textView.layoutManager
                        layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
                        layoutManager?.removeTemporaryAttribute(.shadow, forCharacterRange: fullRange)
                        
                        if let current = currentBracketRange, let matching = matchingBracketRange {
                            let glowShadow = NSShadow()
                            glowShadow.shadowBlurRadius = 5
                            glowShadow.shadowColor = self.parent.themeColor
                            glowShadow.shadowOffset = NSSize(width: 0, height: 0)
                            
                            let highlightAttrs: [NSAttributedString.Key: Any] = [
                                .backgroundColor: self.parent.themeColor.withAlphaComponent(0.25),
                                .shadow: self.parent.isHaloEffectEnabled ? glowShadow : NSShadow()
                            ]
                            
                            layoutManager?.addTemporaryAttributes(highlightAttrs, forCharacterRange: current)
                            layoutManager?.addTemporaryAttributes(highlightAttrs, forCharacterRange: matching)
                        }
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

    private func applyAIResult(_ aiRes: AIResult, to textView: NSTextView) {
        let range = aiRes.range
        let text = aiRes.result
        
        // Verificar rango para evitar crash
        let currentLen = (textView.string as NSString).length
        guard range.location + range.length <= currentLen else { return }
        
        if textView.shouldChangeText(in: range, replacementString: text) {
            textView.replaceCharacters(in: range, with: text)
            textView.didChangeText()
            // Notificar que el texto cambió para que SwiftUI lo sepa
            DispatchQueue.main.async {
                self.text = textView.string
            }
        }
    }
}

struct AIResult: Equatable {
    let result: String
    let range: NSRange
    let id = UUID()
}
