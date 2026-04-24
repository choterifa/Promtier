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
    let label: String
    @Binding var hotkeyCode: Int
    @Binding var hotkeyModifiers: Int
    let defaultKeyCode: Int
    let defaultModifiers: Int
    
    @State private var isRecording = false
    @State private var localMonitor: Any?
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
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
                    hotkeyCode = -1
                    hotkeyModifiers = 0
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Sin atajo")
                
                Button(action: {
                    hotkeyCode = defaultKeyCode
                    hotkeyModifiers = defaultModifiers
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Restablecer atajo")
            } else {
                Button(action: {
                    stopRecording()
                }) {
                    Text("Cancelar")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    
    private var shortcutString: String {
        return ShortcutFormatter.format(keyCode: hotkeyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(hotkeyModifiers)))
    }
    
    @State private var globalMonitorId: UUID?
    
    private func startRecording() {
        isRecording = true
        
        // Monitor local para capturar teclas
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown]) { event in
            if event.type == .leftMouseDown {
                stopRecording()
                return event
            }
            
            if event.type == .flagsChanged {
                return event
            }
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Delete / Backspace para borrar
            if event.keyCode == 51 {
                hotkeyCode = -1
                hotkeyModifiers = 0
                stopRecording()
                return nil
            }
            
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
            hotkeyCode = Int(event.keyCode)
            hotkeyModifiers = Int(modifiers.rawValue)
            
            stopRecording()
            return nil
        }
        
        globalMonitorId = GlobalHotkeyManager.shared.subscribeToGlobalEvents { _ in
            stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let id = globalMonitorId {
            GlobalHotkeyManager.shared.unsubscribeFromGlobalEvents(id: id)
            globalMonitorId = nil
        }
    }
}

// MARK: - Grabador de atajos reutilizable (para prompts individuales)
struct ReusableShortcutRecorderView: View {
    let title: String
    @Binding var shortcutString: String?
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var isHovering = false
    @State private var isHoveringClear = false
    
    private var formattedShortcut: String {
        guard let shortcut = shortcutString, let (keyCode, modifiers) = parseShortcut(shortcut) else { return "Ninguno" }
        return ShortcutFormatter.format(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func parseShortcut(_ shortcut: String) -> (Int, NSEvent.ModifierFlags)? {
        let parts = shortcut.split(separator: ":")
        guard parts.count == 2,
              let keyCode = Int(parts[0]),
              let modifiersValue = UInt(parts[1]) else { return nil }
        return (keyCode, NSEvent.ModifierFlags(rawValue: modifiersValue))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            
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
                        Text("Presiona...")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .opacity(isRecording ? 1 : 0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
                    } else {
                        Text(formattedShortcut)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.blue.opacity(0.15) : Color.primary.opacity(isHovering ? 0.1 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.blue : (isHovering ? Color.primary.opacity(0.2) : Color.clear), lineWidth: 1)
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
            }
            .buttonStyle(.plain)
            
            if !isRecording && shortcutString != nil {
                Button(action: {
                    shortcutString = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isHoveringClear ? .red : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHoveringClear = hovering
                    }
                }
                .help("Eliminar atajo")
            } else if isRecording {
                Button(action: {
                    stopRecording()
                }) {
                    Text("Cancelar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @State private var globalMonitorId: UUID?
    
    private func startRecording() {
        isRecording = true
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown]) { event in
            if event.type == .leftMouseDown {
                stopRecording()
                return event
            }
            
            if event.type == .flagsChanged { return event }
            
            if event.keyCode == 51 { // Backspace
                shortcutString = nil
                stopRecording()
                return nil
            }
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.isEmpty && event.keyCode != 53 { return event }
            
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }
            
            shortcutString = "\(event.keyCode):\(modifiers.rawValue)"
            stopRecording()
            return nil
        }
        
        globalMonitorId = GlobalHotkeyManager.shared.subscribeToGlobalEvents { _ in
            stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let id = globalMonitorId {
            GlobalHotkeyManager.shared.unsubscribeFromGlobalEvents(id: id)
            globalMonitorId = nil
        }
    }
}
