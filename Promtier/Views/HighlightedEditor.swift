//
//  HighlightedEditor.swift
//  Promtier
//
//  COMPONENTE: Editor de texto nativo con resaltado de variables y auto-indentado
//

import SwiftUI
import AppKit

class PassThroughScrollView: NSScrollView {
    private var isMouseInside = false
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseInside = true
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseInside = false
    }
    
    override func scrollWheel(with event: NSEvent) {
        // When mouse is hovering over the editor, always scroll inside it
        if isMouseInside {
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
        let stringLength = string.utf16.count
        let safeRange = NSRange(
            location: max(0, min(range.location, stringLength)),
            length: 0
        )
        
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: safeRange)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
        
        var highlightRects: [NSRect] = []
        
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (rect, usedRect, _, _, _) in
            var adjustedRect = rect
            if let defaultStyle = self.defaultParagraphStyle {
                adjustedRect.size.height -= defaultStyle.paragraphSpacing
            } else {
                adjustedRect.size.height -= 8
            }
            
            let highlightRect = NSRect(
                x: 6,
                y: adjustedRect.origin.y + self.textContainerInset.height,
                width: self.bounds.width - 12,
                height: adjustedRect.height
            )
            highlightRects.append(highlightRect)
        }
        
        for hRect in highlightRects {
            // Rounded background highlight
            let path = NSBezierPath(roundedRect: hRect, xRadius: 6, yRadius: 6)
            currentLineHighlightColor.withAlphaComponent(0.06).setFill()
            path.fill()
            
            // Left accent bar (rounded)
            let barRect = NSRect(x: 2, y: hRect.origin.y + 2, width: 3, height: hRect.height - 4)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: 1.5, yRadius: 1.5)
            currentLineHighlightColor.withAlphaComponent(0.45).setFill()
            barPath.fill()
        }
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
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        
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
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Optimizar para scrolling suave y performance
        textView.textContainerInset = NSSize(width: 10, height: 14)
        textView.textContainer?.lineFragmentPadding = 6
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        // Optimización de renderizado
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Smooth scrolling
        scrollView.contentView.postsBoundsChangedNotifications = false
        
        scrollView.documentView = textView
        
        // Listen for Apple Intelligence trigger notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TriggerAppleIntelligence"), object: nil, queue: .main) { _ in
            if textView.window?.firstResponder == textView {
                textView.showWritingTools(nil)
            }
        }
        
        // Formato Markdown nativo (Preserva Undo/Redo)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("FormatMarkdown"), object: nil, queue: .main) { notification in
            guard textView.window?.firstResponder == textView else { return }
            guard let userInfo = notification.userInfo,
                  let prefix = userInfo["prefix"] as? String,
                  let suffix = userInfo["suffix"] as? String else { return }
            
            let isList = userInfo["isList"] as? Bool ?? false
            let nsString = textView.string as NSString
            let currentSelection = textView.selectedRange()
            
            if isList {
                // Para listas, expandir la selección para cubrir líneas completas
                let lineRange = nsString.lineRange(for: currentSelection)
                let linesText = nsString.substring(with: lineRange)
                
                let lines = linesText.components(separatedBy: "\n")
                var formattedLines: [String] = []
                var counter = 1
                
                let isNumbered = prefix.contains("1.")
                
                for line in lines {
                    // Ignorar la última línea vacía que components(separatedBy:) suele generar si termina en \n
                    if line.isEmpty && line == lines.last { continue }
                    
                    if line.trimmingCharacters(in: .whitespaces).isEmpty {
                        formattedLines.append(line)
                    } else {
                        // Evitar anidamiento: si la línea ya empieza con el marcador, no lo añadimos de nuevo
                        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                        let hasBullet = trimmedLine.hasPrefix("- ")
                        let hasNumber = trimmedLine.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil
                        
                        if (isNumbered && hasNumber) || (!isNumbered && hasBullet) {
                            formattedLines.append(line) // Ya es lista, dejar igual
                        } else {
                            let linePrefix = isNumbered ? "\(counter). " : prefix
                            formattedLines.append(linePrefix + line + suffix)
                            counter += 1
                        }
                    }
                }
                
                let newText = formattedLines.joined(separator: "\n") + (linesText.hasSuffix("\n") ? "\n" : "")
                
                textView.undoManager?.beginUndoGrouping()
                if textView.shouldChangeText(in: lineRange, replacementString: newText) {
                    textView.replaceCharacters(in: lineRange, with: newText)
                    textView.didChangeText()
                    // Restaurar cursor al final de la inserción o seleccionar todo el bloque editado
                    textView.setSelectedRange(NSRange(location: lineRange.location + (newText as NSString).length, length: 0))
                }
                textView.undoManager?.endUndoGrouping()
                
            } else {
                // Formato estándar (Bold, Italic, Code) sobre la selección exacta
                let selectedText = nsString.substring(with: currentSelection)
                let newText = prefix + selectedText + suffix
                let newLength = (selectedText as NSString).length
                
                textView.undoManager?.beginUndoGrouping()
                if textView.shouldChangeText(in: currentSelection, replacementString: newText) {
                    textView.replaceCharacters(in: currentSelection, with: newText)
                    textView.didChangeText()
                    
                    let newLocation = currentSelection.location + (prefix as NSString).length
                    textView.setSelectedRange(NSRange(location: newLocation, length: newLength))
                }
                textView.undoManager?.endUndoGrouping()
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
            let nsCurrentText = textView.string as NSString
            let nsNewText = text as NSString
            
            // Usar textStorage para que el cambio sea atómico
            textView.textStorage?.beginEditing()
            textView.textStorage?.replaceCharacters(in: NSRange(location: 0, length: nsCurrentText.length), with: text)
            textView.textStorage?.endEditing()
            
            // Restaurar selección de forma segura
            let maxLen = nsNewText.length
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
                
                // Lógica Inteligente de Auto-indentado y Listas Continuas
                let content = textView.string as NSString
                let lineRange = content.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
                let line = content.substring(with: lineRange)
                
                // Extraer la línea real ignorando saltos de línea finales
                let rawLine = line.replacingOccurrences(of: "\n", with: "")
                let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
                
                // 1. Detección de marcadores vacíos para cancelar la lista (Doble Enter)
                let emptyListMarkers = ["- ", "* ", "• "]
                let isEmptyBullet = emptyListMarkers.contains(trimmedLine)
                let isEmptyNumber = trimmedLine.range(of: "^\\d+\\.\\s$", options: .regularExpression) != nil
                
                if isEmptyBullet || isEmptyNumber {
                    // Borrar el marcador vacío actual y saltar de línea normalmente
                    textView.undoManager?.beginUndoGrouping()
                    textView.replaceCharacters(in: lineRange, with: "\n")
                    textView.undoManager?.endUndoGrouping()
                    return false
                }
                
                // 2. Extraer indentación base (espacios al inicio)
                var indentation = ""
                for char in rawLine {
                    if char == " " || char == "\t" {
                        indentation.append(char)
                    } else { break }
                }
                
                // 3. Continuación de listas
                var nextPrefix = ""
                if trimmedLine.hasPrefix("- ") {
                    nextPrefix = "- "
                } else if trimmedLine.hasPrefix("* ") {
                    nextPrefix = "* "
                } else if trimmedLine.hasPrefix("• ") {
                    nextPrefix = "• "
                } else if let match = trimmedLine.range(of: "^(\\d+)\\.\\s", options: .regularExpression) {
                    // Auto-incremento de listas numeradas
                    let prefixStr = String(trimmedLine[match])
                    if let numberStr = prefixStr.components(separatedBy: ".").first, let number = Int(numberStr) {
                        nextPrefix = "\(number + 1). "
                    } else {
                        nextPrefix = "1. " // Fallback de seguridad
                    }
                }
                
                // 4. Aplicar auto-indentado o lista
                if !indentation.isEmpty || !nextPrefix.isEmpty {
                    let newString = "\n" + indentation + nextPrefix
                    textView.undoManager?.beginUndoGrouping()
                    textView.insertText(newString, replacementRange: affectedCharRange)
                    textView.undoManager?.endUndoGrouping()
                    return false
                }
            }
            return true
        }
        
        // Timer para debounce del resaltado
        private var highlightTimer: Timer?
        private var lastHighlightedText: String?
        
        // MARK: - Highlighting Logic (Optimized)
        
        private static let varRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])
        private static let bracketRegex = try? NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
        private static let chainRegex = try? NSRegularExpression(pattern: "\\[\\[@Prompt:([^\\]]+)\\]\\]", options: [])
        
        // Markdown Regexes
        private static let mdHeaderRegex = try? NSRegularExpression(pattern: "^#{1,6}\\s+.*$", options: [.anchorsMatchLines])
        private static let mdBoldRegex = try? NSRegularExpression(pattern: "\\*\\*([^\\*]+)\\*\\*|__([^\\_]+)__", options: [])
        private static let mdItalicRegex = try? NSRegularExpression(pattern: "(?<![\\*\\w])\\*([^\\*\\s][^\\*]*[^\\*\\s])\\*(?![\\*\\w])|(?<![_\\w])_([^_\\s][^_]*[^_\\s])_(?![_\\w])", options: [])
        private static let mdInlineCodeRegex = try? NSRegularExpression(pattern: "(?<!`)`(?!`)([^`\\n]+?)(?<!`)`(?!`)", options: [])
        private static let mdCodeBlockRegex = try? NSRegularExpression(pattern: "```[^\\n]*\\n[\\s\\S]*?```", options: [])
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
                    
                    let fullNSRange = NSRange(text.startIndex..., in: text)
                    
                    let varMatches = Self.varRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let bracketMatches = Self.bracketRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let chainMatches = Self.chainRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    
                    // Markdown matches
                    let headerMatches = Self.mdHeaderRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let boldMatches = Self.mdBoldRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let italicMatches = Self.mdItalicRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let inlineCodeMatches = Self.mdInlineCodeRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let codeBlockMatches = Self.mdCodeBlockRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let linkMatches = Self.mdLinkRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    let listMatches = Self.mdListRegex?.matches(in: text, options: [], range: fullNSRange) ?? []
                    
                    // Build a set of ranges inside code blocks to skip for inline code
                    let codeBlockRangeSet = codeBlockMatches.map { $0.range }
                    let filteredInlineCode = inlineCodeMatches.filter { inlineMatch in
                        !codeBlockRangeSet.contains(where: { blockRange in
                            NSIntersectionRange(blockRange, inlineMatch.range).length > 0
                        })
                    }
                    
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
                        if textStorage.string != text { return }
                        
                        let fullRange = NSRange(location: 0, length: textStorage.length)
                        let baseFont = NSFont.systemFont(ofSize: fontSize)
                        let boldFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
                        let semiboldFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
                        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        let codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
                        let codeFontBold = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .medium)
                        
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.lineSpacing = 5
                        paragraphStyle.paragraphSpacing = 10
                        
                        // Indented paragraph style for code blocks
                        let codeBlockParagraphStyle = NSMutableParagraphStyle()
                        codeBlockParagraphStyle.lineSpacing = 3
                        codeBlockParagraphStyle.paragraphSpacing = 4
                        codeBlockParagraphStyle.headIndent = 12
                        codeBlockParagraphStyle.firstLineHeadIndent = 12
                        
                        textStorage.beginEditing()
                        
                        // 1. Reset base attributes
                        let baseAttributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.labelColor,
                            .font: baseFont,
                            .paragraphStyle: paragraphStyle
                        ]
                        textStorage.setAttributes(baseAttributes, range: fullRange)
                        
                        let syntaxColor = NSColor.labelColor.withAlphaComponent(0.22)
                        
                        // 2. Markdown Pass
                        
                        // Headers
                        for match in headerMatches {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize + 1, weight: .heavy), range: match.range)
                            
                            if let hashRange = text.range(of: "^#{1,6}\\s+", options: .regularExpression, range: Range(match.range, in: text)!) {
                                let nsHashRange = NSRange(hashRange, in: text)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: nsHashRange)
                            }
                        }
                        
                        // Bold
                        for match in boldMatches {
                            textStorage.addAttribute(.font, value: boldFont, range: match.range)
                            if match.numberOfRanges >= 1 {
                                let startMarker = NSRange(location: match.range.location, length: 2)
                                let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: startMarker)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: endMarker)
                            }
                        }
                        
                        // Italic
                        for match in italicMatches {
                            textStorage.addAttribute(.font, value: italicFont, range: match.range)
                            if match.numberOfRanges >= 1 {
                                let startMarker = NSRange(location: match.range.location, length: 1)
                                let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: startMarker)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: endMarker)
                            }
                        }
                        
                        // Code Blocks (``` ... ```)
                        for match in codeBlockMatches {
                            textStorage.addAttribute(.font, value: codeFont, range: match.range)
                            textStorage.addAttribute(.foregroundColor, value: NSColor.systemGreen.withAlphaComponent(0.85), range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: NSColor.black.withAlphaComponent(0.15), range: match.range)
                            textStorage.addAttribute(.paragraphStyle, value: codeBlockParagraphStyle, range: match.range)
                            
                            // Dim the ``` fences
                            let fenceText = nsText.substring(with: match.range)
                            if let openEnd = fenceText.range(of: "\n") {
                                let openLen = fenceText.distance(from: fenceText.startIndex, to: openEnd.lowerBound)
                                let openRange = NSRange(location: match.range.location, length: openLen)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: openRange)
                            }
                            // Dim the closing ```
                            let closeLen = 3
                            if match.range.length >= closeLen {
                                let closeRange = NSRange(location: match.range.location + match.range.length - closeLen, length: closeLen)
                                textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: closeRange)
                            }
                        }
                        
                        // Inline Code (`code`) — Professional pill-style
                        let inlineCodeBg: NSColor
                        let inlineCodeFg: NSColor
                        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                            inlineCodeBg = NSColor(red: 0.2, green: 0.22, blue: 0.28, alpha: 1.0)
                            inlineCodeFg = NSColor(red: 0.85, green: 0.65, blue: 0.95, alpha: 1.0) // Soft purple
                        } else {
                            inlineCodeBg = NSColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1.0)
                            inlineCodeFg = NSColor(red: 0.72, green: 0.22, blue: 0.55, alpha: 1.0) // Rose-purple
                        }
                        
                        for match in filteredInlineCode {
                            textStorage.addAttribute(.font, value: codeFontBold, range: match.range)
                            textStorage.addAttribute(.foregroundColor, value: inlineCodeFg, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: inlineCodeBg, range: match.range)
                            
                            // Dim backticks
                            let startTick = NSRange(location: match.range.location, length: 1)
                            let endTick = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                            textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: startTick)
                            textStorage.addAttribute(.foregroundColor, value: syntaxColor, range: endTick)
                        }
                        
                        // Links
                        for match in linkMatches {
                            textStorage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: match.range)
                            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                        }
                        
                        // Lists — Use theme color for markers
                        let listMarkerColor = self.parent.isHaloEffectEnabled ? self.parent.themeColor : NSColor.systemOrange
                        for match in listMatches {
                            textStorage.addAttribute(.foregroundColor, value: listMarkerColor, range: match.range)
                            textStorage.addAttribute(.font, value: semiboldFont, range: match.range)
                        }

                        // 3. Syntax Pass (High priority)
                        for match in bracketMatches {
                            // Skip brackets inside code blocks/inline code
                            let inCode = codeBlockRangeSet.contains(where: { NSIntersectionRange($0, match.range).length > 0 })
                                || filteredInlineCode.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 })
                            if inCode { continue }
                            
                            textStorage.addAttribute(.foregroundColor, value: self.parent.themeColor, range: match.range)
                            textStorage.addAttribute(.font, value: boldFont, range: match.range)
                        }
                        
                        for match in varMatches {
                            let varColor = self.parent.isHaloEffectEnabled ? NSColor.systemBlue : self.parent.themeColor
                            textStorage.addAttribute(.foregroundColor, value: varColor, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: varColor.withAlphaComponent(0.08), range: match.range)
                            textStorage.addAttribute(.font, value: boldFont, range: match.range)
                        }
                        
                        for match in chainMatches {
                            textStorage.addAttribute(.foregroundColor, value: self.parent.themeColor, range: match.range)
                            textStorage.addAttribute(.backgroundColor, value: self.parent.themeColor.withAlphaComponent(0.05), range: match.range)
                            textStorage.addAttribute(.font, value: boldFont, range: match.range)
                            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                        }
                        
                        textStorage.endEditing()
                        
                        // 4. Bracket Matching Pass (Temporary Attributes — no Undo impact)
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
