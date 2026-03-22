//
//  FloatingZenEditorView.swift
//  Promtier
//
//  VISTA: Mini editor flotante estilo spotlight para notas rápidas
//

import SwiftUI

struct FloatingZenEditorView: View {
    @EnvironmentObject var manager: FloatingZenManager
    @EnvironmentObject var preferences: PreferencesManager
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Cabecera arrastrable
            HStack {
                TextField("zen_title_placeholder".localized(for: preferences.language), text: $manager.title)
                    .font(.system(size: 16, weight: .bold))
                    .textFieldStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    manager.hide()
                    // Si el usuario quiere guardar inmediatamente y abrir la app
                    MenuBarManager.shared.showPopover()
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("back_to_app".localized(for: preferences.language))
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider().opacity(0.5)
            
            // TextEditor nativo simple para velocidad y fluidez
            TextEditor(text: $manager.content)
                .font(.system(size: 14 * preferences.fontSize.scale))
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(12)
            
            Divider().opacity(0.5)
            
            // Footer
            HStack {
                Text(String(format: "characters".localized(for: preferences.language), manager.content.count))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("auto_save_active".localized(for: preferences.language))
                    .font(.system(size: 11))
                    .foregroundColor(.green.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .background(FloatingVisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            isFocused = true
        }
    }
}

// Helper para blur
struct FloatingVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
