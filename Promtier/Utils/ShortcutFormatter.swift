//
//  ShortcutFormatter.swift
//  Promtier
//
//  Responsabilidad: Formatear de manera consistente y escalable los atajos de teclado (keyCode + modifiers).
//

import AppKit

struct ShortcutFormatter {
    
    /// Parsea una cadena con formato "keyCode:modifiers" y devuelve el atajo legible
    static func format(shortcutString: String?) -> String? {
        guard let shortcut = shortcutString, !shortcut.isEmpty else { return nil }
        
        let parts = shortcut.split(separator: ":")
        guard parts.count == 2,
              let keyCode = Int(parts[0]),
              let modifiersValue = UInt(parts[1]) else {
            return nil
        }
        
        return format(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiersValue))
    }
    
    /// Formatea un `keyCode` y `NSEvent.ModifierFlags` en un String legible
    static func format(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        if keyCode == -1 { return "Sin atajo" }
        var str = ""
        
        if modifiers.contains(.control) { str += "⌃" }
        if modifiers.contains(.option) { str += "⌥" }
        if modifiers.contains(.shift) { str += "⇧" }
        if modifiers.contains(.command) { str += "⌘" }
        
        str += keyName(for: keyCode)
        
        return str.isEmpty ? "Ninguno" : str
    }
    
    private static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return translateKeyCode(keyCode)
        }
    }
    
    private static func translateKeyCode(_ keyCode: Int) -> String {
        // La traducción de key codes a caracteres legibles usando CGEvent 
        // aplica el layout de teclado actual del sistema.
        let source = CGEventSource(stateID: .combinedSessionState)
        if let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            let nsEvent = NSEvent(cgEvent: cgEvent)
            if let chars = nsEvent?.charactersIgnoringModifiers, !chars.isEmpty {
                return chars.uppercased()
            }
        }
        
        // Fallback al decimal si la traducción falla
        return "\(keyCode)"
    }
}
