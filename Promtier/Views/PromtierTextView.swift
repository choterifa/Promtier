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
    var onPaste: (() -> Void)?
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
            } else if event.charactersIgnoringModifiers == "z" {
                if let um = self.undoManager, um.canUndo {
                    um.undo()
                    return true
                }
            }
        } else if command && shift {
            if event.charactersIgnoringModifiers == "l" {
                PromtierEditorCommandCenter.post(.bulletList, to: editorID)
                return true
            } else if event.charactersIgnoringModifiers == "Z" || event.charactersIgnoringModifiers == "z" {
                if let um = self.undoManager, um.canRedo {
                    um.redo()
                    return true
                }
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

    override func paste(_ sender: Any?) {
        guard let pasteboard = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            onPaste?()
            return
        }
        
        // Forzar plain text paste para evitar problemas de formato y asegurar que el Undo Manager
        // registre correctamente la edición incluso si el editor está vacío.
        self.undoManager?.beginUndoGrouping()
        self.insertText(pasteboard, replacementRange: self.selectedRange())
        self.undoManager?.endUndoGrouping()
        
        onPaste?()
    }
}