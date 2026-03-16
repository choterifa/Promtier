//
//  ShortcutRecorderView.swift
//  Promtier
//
//  COMPONENTE: Grabador de atajos de teclado personalizado
//

import SwiftUI
import AppKit
import Carbon

struct ShortcutRecorderView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isRecording = false
    @State private var localMonitor: Any?
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Atajo de apertura")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 8) {
                    if isRecording {
                        Text("Presiona las teclas...")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .opacity(isRecording ? 1 : 0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
                    } else {
                        Text(shortcutString)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.blue.opacity(0.1) : Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            if !isRecording {
                Button(action: {
                    preferences.hotkeyCode = 35 // P
                    preferences.hotkeyModifiers = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Restablecer atajo")
            }
        }
    }
    
    private var shortcutString: String {
        return ShortcutFormatter.format(keyCode: preferences.hotkeyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(preferences.hotkeyModifiers)))
    }
    
    private func startRecording() {
        isRecording = true
        
        // Monitor local para capturar teclas
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                return event
            }
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Requerir al menos un modificador (Cmd, Opt, Ctrl, Shift)
            if modifiers.isEmpty && event.keyCode != 53 { // 53 is Escape
                return event
            }
            
            // Escape para cancelar
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            // Guardar el atajo
            preferences.hotkeyCode = Int(event.keyCode)
            preferences.hotkeyModifiers = Int(modifiers.rawValue)
            
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

// MARK: - Helper de Formateo
struct ShortcutFormatter {
    static func format(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
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
            // Simplificado: obtener carácter legible para la UI según el Key Code
            switch keyCode {
            case 0: return "A"
            case 1: return "S"
            case 2: return "D"
            case 3: return "F"
            case 4: return "H"
            case 5: return "G"
            case 6: return "Z"
            case 7: return "X"
            case 8: return "C"
            case 9: return "V"
            case 11: return "B"
            case 12: return "Q"
            case 13: return "W"
            case 14: return "E"
            case 15: return "R"
            case 16: return "Y"
            case 17: return "T"
            case 31: return "O"
            case 32: return "U"
            case 34: return "I"
            case 35: return "P"
            case 37: return "L"
            case 38: return "J"
            case 40: return "K"
            case 45: return "N"
            case 46: return "M"
            default: return String(format: "%X", keyCode)
            }
        }
    }
}
