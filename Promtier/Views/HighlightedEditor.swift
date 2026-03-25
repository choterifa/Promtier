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
    var editorID: String = ""
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        
        if command && !shift {
            if event.charactersIgnoringModifiers == "b" {
                PromtierEditorCommandCenter.post(.bold, to: editorID)
                return true
            } else if event.charactersIgnoringModifiers == "i" {
                PromtierEditorCommandCenter.post(.italic, to: editorID)
                return true
            } else if event.charactersIgnoringModifiers == "]" {
                PromtierEditorCommandCenter.post(.indent, to: editorID)
                return true
            }
        } else if command && shift {
            if event.charactersIgnoringModifiers == "l" {
                PromtierEditorCommandCenter.post(.bulletList, to: editorID)
                return true
            }
        }
        
        // Let Tab handle indent if multi-line selection
        if event.keyCode == 48 && selectedRange().length > 0 { // Tab key
            if event.modifierFlags.contains(.shift) {
                PromtierEditorCommandCenter.post(.outdent, to: editorID)
            } else {
                PromtierEditorCommandCenter.post(.indent, to: editorID)
            }
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

struct HighlightedEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var plainText: String
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
        textView.editorID = editorID
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesRuler = false
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
        context.coordinator.installObservers(for: textView)
        context.coordinator.loadMarkdownIfNeeded(into: textView, markdown: text)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PromtierTextView else { return }

        if context.coordinator.lastSerializedMarkdown != text {
            context.coordinator.loadMarkdownIfNeeded(into: textView, markdown: text)
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
                self.plainText = textView.string
                self.text = context.coordinator.serializedMarkdown(from: textView)
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
                self.plainText = textView.string
                self.text = context.coordinator.serializedMarkdown(from: textView)
                self.replaceSnippetRequest = nil
                self.showSnippets = false
            }
        }
        
        // triggerAIRequest is now handled by the parent view for Ollama integration
        
        // Actualizar fuente si cambió
        if textView.font?.pointSize != fontSize {
            textView.font = .systemFont(ofSize: fontSize)
            context.coordinator.loadMarkdownIfNeeded(into: textView, markdown: text, force: true)
        }
        
        // Manejar petición de foco
        if let focusRequest = focusRequest, focusRequest.wrappedValue {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                focusRequest.wrappedValue = false
            }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.teardownObservers()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        private enum HighlightMode {
            case full
            case bracketOnly
        }

        var parent: HighlightedEditor
        var observerTokens: [NSObjectProtocol] = []
        var lastSerializedMarkdown: String = ""
        private var isApplyingExternalUpdate = false
        private var highlightWorkItem: DispatchWorkItem?
        private var appliedBracketRanges: [NSRange] = []
        
        init(_ parent: HighlightedEditor) {
            self.parent = parent
        }

        deinit {
            highlightWorkItem?.cancel()
            teardownObservers()
        }

        func installObservers(for textView: PromtierTextView) {
            teardownObservers()

            let aiToken = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("TriggerAppleIntelligence"),
                object: nil,
                queue: .main
            ) { [weak textView] _ in
                guard let textView = textView, textView.window?.firstResponder == textView else { return }
                textView.showWritingTools(nil)
            }

            let commandToken = NotificationCenter.default.addObserver(
                forName: .promtierEditorCommand,
                object: nil,
                queue: .main
            ) { [weak self, weak textView] notification in
                guard let self = self, let textView = textView else { return }
                guard let targetID = notification.userInfo?["editorID"] as? String, targetID == self.parent.editorID else { return }
                guard let rawAction = notification.userInfo?["action"] as? String,
                      let action = PromtierEditorCommandAction(rawValue: rawAction) else { return }
                guard textView.window?.firstResponder == textView else { return }
                self.handleEditorCommand(action, in: textView)
            }

            observerTokens = [aiToken, commandToken]
        }

        func teardownObservers() {
            observerTokens.forEach(NotificationCenter.default.removeObserver)
            observerTokens.removeAll()
        }

        func loadMarkdownIfNeeded(into textView: PromtierTextView, markdown: String, force: Bool = false) {
            guard force || lastSerializedMarkdown != markdown else { return }

            isApplyingExternalUpdate = true
            let selectedRanges = textView.selectedRanges
            let attributed = MarkdownRTFConverter.parseMarkdown(
                markdown,
                baseFont: .systemFont(ofSize: parent.fontSize),
                textColor: .labelColor
            )

            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(attributed)
            textView.textStorage?.endEditing()

            MarkdownRTFConverter.applyParagraphStyles(
                to: textView.textStorage ?? NSMutableAttributedString(),
                baseFont: .systemFont(ofSize: parent.fontSize)
            )

            if let safe = selectedRanges.first?.rangeValue,
               safe.location + safe.length <= textView.string.utf16.count {
                textView.selectedRanges = selectedRanges
            } else {
                textView.setSelectedRange(NSRange(location: min(markdown.count, textView.string.utf16.count), length: 0))
            }

            parent.plainText = textView.string
            lastSerializedMarkdown = markdown
            syncTypingAttributes(for: textView)
            scheduleHighlighting(for: textView, mode: .full, debounce: false)
            isApplyingExternalUpdate = false
        }

        func serializedMarkdown(from textView: NSTextView) -> String {
            MarkdownRTFConverter.generateMarkdown(from: textView.attributedString())
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if isApplyingExternalUpdate { return }
            MarkdownRTFConverter.applyParagraphStyles(
                to: textView.textStorage ?? NSMutableAttributedString(),
                baseFont: .systemFont(ofSize: parent.fontSize)
            )

            let markdown = serializedMarkdown(from: textView)
            lastSerializedMarkdown = markdown
            self.parent.text = markdown
            self.parent.plainText = textView.string
            self.parent.selectedRange = textView.selectedRange()
            syncTypingAttributes(for: textView)
            scheduleHighlighting(for: textView, mode: .full)
            
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
            scheduleHighlighting(for: textView, mode: .bracketOnly, debounce: false)
            syncTypingAttributes(for: textView)
            
            // Notion-style floating format menu
            let range = textView.selectedRange()
            if range.length > 0 {
                if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    var boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    boundingRect.origin.x += textView.textContainerOrigin.x
                    boundingRect.origin.y += textView.textContainerOrigin.y
                    FormatMenuPopover.shared.show(
                        in: textView,
                        at: boundingRect,
                        editorID: parent.editorID,
                        themeColor: parent.themeColor
                    )
                }
            } else {
                FormatMenuPopover.shared.hide()
            }
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            guard notification.object as? NSTextView != nil else { return }
            DispatchQueue.main.async {
                self.parent.isFocused = true
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            guard notification.object as? NSTextView != nil else { return }
            DispatchQueue.main.async {
                self.parent.isFocused = false
            }
        }

        private func handleEditorCommand(_ action: PromtierEditorCommandAction, in textView: NSTextView) {
            switch action {
            case .bold:
                toggleTrait(.boldFontMask, in: textView)
            case .italic:
                toggleTrait(.italicFontMask, in: textView)
            case .inlineCode:
                toggleInlineCode(in: textView)
            case .bulletList:
                applyList(prefix: "- ", in: textView)
            case .numberedList:
                applyNumberedList(in: textView)
            case .indent:
                indentSelection(in: textView)
            case .outdent:
                outdentSelection(in: textView)
            }
        }

        private func toggleTrait(_ trait: NSFontTraitMask, in textView: NSTextView) {
            let selection = textView.selectedRange()
            let baseFont = NSFont.systemFont(ofSize: parent.fontSize)

            textView.undoManager?.beginUndoGrouping()

            if selection.length == 0 {
                var typing = textView.typingAttributes
                let current = (typing[.font] as? NSFont) ?? baseFont
                typing[.font] = MarkdownRTFConverter.toggledFont(from: current, add: trait)
                textView.typingAttributes = typing
            } else {
                textView.textStorage?.beginEditing()
                textView.textStorage?.enumerateAttribute(.font, in: selection, options: []) { value, subRange, _ in
                    let current = (value as? NSFont) ?? baseFont
                    let updated = MarkdownRTFConverter.toggledFont(from: current, add: trait)
                    textView.textStorage?.addAttribute(.font, value: updated, range: subRange)
                }
                textView.textStorage?.endEditing()
            }

            textView.didChangeText()
            textView.undoManager?.endUndoGrouping()
        }

        private func toggleInlineCode(in textView: NSTextView) {
            let selection = textView.selectedRange()
            let baseFont = NSFont.systemFont(ofSize: parent.fontSize)
            let codeFont = NSFont.monospacedSystemFont(ofSize: max(11, parent.fontSize - 1), weight: .regular)
            let codeBackground = NSColor.secondaryLabelColor.withAlphaComponent(0.12)
            let codeForeground = NSColor.labelColor

            textView.undoManager?.beginUndoGrouping()

            if selection.length == 0 {
                var typing = textView.typingAttributes
                let isCode = (typing[.promtierInlineCode] as? Bool) == true
                if isCode {
                    typing[.font] = baseFont
                    typing[.promtierInlineCode] = nil
                    typing[.backgroundColor] = nil
                    typing[.foregroundColor] = NSColor.labelColor
                } else {
                    typing[.font] = codeFont
                    typing[.promtierInlineCode] = true
                    typing[.backgroundColor] = codeBackground
                    typing[.foregroundColor] = codeForeground
                }
                textView.typingAttributes = typing
            } else {
                let isEntireSelectionCode = isCodeRange(selection, in: textView)
                textView.textStorage?.beginEditing()
                if isEntireSelectionCode {
                    textView.textStorage?.removeAttribute(.promtierInlineCode, range: selection)
                    textView.textStorage?.removeAttribute(.backgroundColor, range: selection)
                    textView.textStorage?.addAttribute(.font, value: baseFont, range: selection)
                    textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.labelColor, range: selection)
                } else {
                    textView.textStorage?.addAttributes([
                        .font: codeFont,
                        .backgroundColor: codeBackground,
                        .foregroundColor: codeForeground,
                        .promtierInlineCode: true
                    ], range: selection)
                }
                textView.textStorage?.endEditing()
            }

            textView.didChangeText()
            textView.undoManager?.endUndoGrouping()
        }

        private func isCodeRange(_ range: NSRange, in textView: NSTextView) -> Bool {
            guard range.length > 0 else { return false }
            var foundPlain = false
            textView.textStorage?.enumerateAttribute(.promtierInlineCode, in: range, options: []) { value, _, stop in
                if (value as? Bool) != true {
                    foundPlain = true
                    stop.pointee = true
                }
            }
            return !foundPlain
        }

        private func applyList(prefix: String, in textView: NSTextView) {
            transformSelectedLines(in: textView) { lines in
                lines.map { line in
                    if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                    if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") { return line }
                    return prefix + line
                }
            }
        }

        private func applyNumberedList(in textView: NSTextView) {
            transformSelectedLines(in: textView) { lines in
                var counter = 1
                return lines.map { line in
                    if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                    if line.trimmingCharacters(in: .whitespaces).range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
                        return line
                    }
                    defer { counter += 1 }
                    return "\(counter). \(line)"
                }
            }
        }

        private func indentSelection(in textView: NSTextView) {
            transformSelectedLines(in: textView) { lines in
                lines.map { "\t" + $0 }
            }
        }

        private func outdentSelection(in textView: NSTextView) {
            transformSelectedLines(in: textView) { lines in
                lines.map { line in
                    if line.hasPrefix("\t") {
                        return String(line.dropFirst())
                    }
                    if line.hasPrefix("    ") {
                        return String(line.dropFirst(4))
                    }
                    return line
                }
            }
        }

        private func transformSelectedLines(in textView: NSTextView, transform: ([String]) -> [String]) {
            let nsString = textView.string as NSString
            let selection = textView.selectedRange()
            let lineRange = nsString.lineRange(for: selection)
            let lineBlock = nsString.substring(with: lineRange)
            let trailingNewline = lineBlock.hasSuffix("\n")
            var lines = lineBlock.components(separatedBy: "\n")
            if trailingNewline, lines.last == "" {
                lines.removeLast()
            }

            let transformed = transform(lines)
            let newText = transformed.joined(separator: "\n") + (trailingNewline ? "\n" : "")

            textView.undoManager?.beginUndoGrouping()
            if textView.shouldChangeText(in: lineRange, replacementString: newText) {
                textView.replaceCharacters(in: lineRange, with: newText)
                textView.setSelectedRange(NSRange(location: lineRange.location, length: (newText as NSString).length))
                textView.didChangeText()
            }
            textView.undoManager?.endUndoGrouping()
        }

        private func syncTypingAttributes(for textView: NSTextView) {
            guard textView.selectedRange().length == 0 else { return }
            let paragraphStyle = MarkdownRTFConverter.defaultParagraphStyle()
            if textView.string.isEmpty {
                textView.typingAttributes = [
                    .font: NSFont.systemFont(ofSize: parent.fontSize),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraphStyle
                ]
                return
            }

            let maxIndex = max(0, textView.string.utf16.count - 1)
            let caretLocation = max(0, min(textView.selectedRange().location, maxIndex))
            var attrs = textView.textStorage?.attributes(at: caretLocation, effectiveRange: nil) ?? textView.typingAttributes
            attrs[.paragraphStyle] = attrs[.paragraphStyle] ?? paragraphStyle
            attrs[.foregroundColor] = attrs[.foregroundColor] ?? NSColor.labelColor
            textView.typingAttributes = attrs
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
        
        // MARK: - Highlighting Logic (Rich Text + Temporary Overlays)
        
        private static let varRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])
        private static let chainRegex = try? NSRegularExpression(pattern: "\\[\\[@Prompt:([^\\]]+)\\]\\]", options: [])
        private static let listRegex = try? NSRegularExpression(pattern: "^\\s*([-*+]|\\d+\\.)\\s+", options: [.anchorsMatchLines])

        private func scheduleHighlighting(for textView: NSTextView, mode: HighlightMode, debounce: Bool = true) {
            if mode == .full {
                highlightWorkItem?.cancel()
            }

            let delay = debounce ? 0.03 : 0
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.applyHighlighting(to: textView, mode: mode)
            }

            if mode == .full {
                highlightWorkItem = workItem
            }

            if delay == 0 {
                DispatchQueue.main.async(execute: workItem)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }

        private func applyHighlighting(to textView: NSTextView, mode: HighlightMode) {
            let text = textView.string

            if text.isEmpty {
                if mode == .full {
                    clearFullDecorations(in: textView)
                }
                clearBracketHighlight(in: textView)
                return
            }

            if mode == .full {
                applyFullDecorations(in: textView, text: text)
            }
            applyBracketHighlight(in: textView, text: text)
        }

        private func applyFullDecorations(in textView: NSTextView, text: String) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage,
                  textStorage.string == text else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)

            let listMatches = Self.listRegex?.matches(in: text, options: [], range: fullRange) ?? []
            let variableMatches = Self.varRegex?.matches(in: text, options: [], range: fullRange) ?? []
            let chainMatches = Self.chainRegex?.matches(in: text, options: [], range: fullRange) ?? []

            let listMarkerColor = parent.isHaloEffectEnabled ? parent.themeColor : NSColor.systemOrange
            for match in listMatches {
                layoutManager.addTemporaryAttributes([
                    .foregroundColor: listMarkerColor
                ], forCharacterRange: match.range)
            }

            let variableColor = parent.isHaloEffectEnabled ? NSColor.systemBlue : parent.themeColor
            for match in variableMatches {
                layoutManager.addTemporaryAttributes([
                    .foregroundColor: variableColor,
                    .backgroundColor: variableColor.withAlphaComponent(0.1)
                ], forCharacterRange: match.range)
            }

            for match in chainMatches {
                layoutManager.addTemporaryAttributes([
                    .foregroundColor: parent.themeColor,
                    .backgroundColor: parent.themeColor.withAlphaComponent(0.06),
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], forCharacterRange: match.range)
            }
        }

        private func clearFullDecorations(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else { return }
            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
        }

        private func applyBracketHighlight(in textView: NSTextView, text: String) {
            guard let layoutManager = textView.layoutManager else { return }

            clearBracketHighlight(in: textView)

            let selection = textView.selectedRange()
            guard selection.length == 0 else { return }

            let nsText = text as NSString
            let positionsToCheck = [selection.location - 1, selection.location].filter { $0 >= 0 && $0 < nsText.length }

            for position in positionsToCheck {
                let bracket = nsText.substring(with: NSRange(location: position, length: 1))
                guard "{}[]()".contains(bracket),
                      let partner = findMatchingBracket(in: text, for: bracket, at: position) else { continue }

                let glowShadow = NSShadow()
                glowShadow.shadowBlurRadius = parent.isHaloEffectEnabled ? 6 : 3
                glowShadow.shadowColor = parent.themeColor.withAlphaComponent(parent.isHaloEffectEnabled ? 0.8 : 0.45)
                glowShadow.shadowOffset = .zero

                let ranges = [
                    NSRange(location: position, length: 1),
                    NSRange(location: partner, length: 1)
                ]

                for range in ranges {
                    layoutManager.addTemporaryAttributes([
                        .shadow: glowShadow
                    ], forCharacterRange: range)
                }

                appliedBracketRanges = ranges
                break
            }
        }

        private func clearBracketHighlight(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else { return }
            let textLength = textView.string.utf16.count
            for range in appliedBracketRanges where range.location < textLength {
                let safeRange = NSRange(
                    location: range.location,
                    length: min(range.length, textLength - range.location)
                )
                guard safeRange.length > 0 else { continue }
                layoutManager.removeTemporaryAttribute(.shadow, forCharacterRange: safeRange)
            }
            appliedBracketRanges.removeAll()
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
                self.plainText = textView.string
                self.text = MarkdownRTFConverter.generateMarkdown(from: textView.attributedString())
            }
        }
    }
}

class FormatMenuPopover {
    static let shared = FormatMenuPopover()
    private var popover: NSPopover?
    private var hideWorkItem: DispatchWorkItem?
    private var lastEditorID: String?
    
    func show(in view: NSView, at rect: NSRect, editorID: String, themeColor: NSColor) {
        hideWorkItem?.cancel()

        if popover == nil {
            popover = NSPopover()
            popover?.behavior = .transient
            popover?.animates = false
        }

        popover?.contentSize = NSSize(width: 290, height: 54)
        let rootView = AnyView(FloatingFormatBar(editorID: editorID, themeColor: Color(themeColor)))
        if let hostingController = popover?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
        } else {
            popover?.contentViewController = NSHostingController(rootView: rootView)
        }

        if popover?.isShown == true, lastEditorID == editorID {
            popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        } else {
            popover?.close()
            popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        }

        lastEditorID = editorID
    }
    
    func hide() {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.popover?.close()
            self?.lastEditorID = nil
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }
}

struct FloatingFormatBar: View {
    let editorID: String
    let themeColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            formatButton(icon: "bold", action: .bold)
            formatButton(icon: "italic", action: .italic)
            formatButton(icon: "chevron.left.forwardslash.chevron.right", action: .inlineCode)

            separator

            formatButton(icon: "list.bullet", action: .bulletList)
            formatButton(icon: "list.number", action: .numberedList)

            separator

            formatButton(icon: "increase.indent", action: .indent)
            formatButton(icon: "decrease.indent", action: .outdent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
        )
        .padding(8)
    }
    
    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }

    private func formatButton(icon: String, action: PromtierEditorCommandAction) -> some View {
        Button(action: {
            PromtierEditorCommandCenter.post(action, to: editorID)
            HapticService.shared.playLight()
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeColor)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(themeColor.opacity(0.1))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct AIResult: Equatable {
    let result: String
    let range: NSRange
    let id = UUID()
}
