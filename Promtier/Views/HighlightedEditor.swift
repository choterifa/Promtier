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
    var fontSize: CGFloat
    
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
        }
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if replacementString == "\n" {
                // Lógica de Auto-indentado
                let content = textView.string as NSString
                let lineRange = content.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
                let line = content.substring(with: lineRange)
                
                var indentation = ""
                for char in line {
                    if char == " " || char == "\t" {
                        indentation.append(char)
                    } else {
                        break
                    }
                }
                
                if !indentation.isEmpty {
                    let newString = "\n" + indentation
                    textView.insertText(newString, replacementRange: affectedCharRange)
                    return false
                }
            }
            return true
        }
        
        func applyHighlighting(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            // Comenzar edición masiva
            textStorage.beginEditing()
            
            // Resetear estilos base
            textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            textStorage.addAttribute(.backgroundColor, value: NSColor.clear, range: fullRange)
            textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: parent.fontSize), range: fullRange)
            
            // Regex para variables {{variable}}
            let pattern = "\\{\\{([^}]+)\\}\\}"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    let range = match.range
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                    textStorage.addAttribute(.backgroundColor, value: NSColor.systemBlue.withAlphaComponent(0.08), range: range)
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: parent.fontSize, weight: .bold), range: range)
                }
            }
            
            textStorage.endEditing()
        }
    }
}
