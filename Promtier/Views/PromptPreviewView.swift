//
//  PromptPreviewView.swift
//  Promtier
//
//  VISTA: Popover de preview estilo Finder para prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct PromptPreviewView: View {
    let prompt: Prompt
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con título
            HStack {
                Text(prompt.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Botón de cerrar
                Button(action: {
                    // Cerrar el popover desde adentro
                    if let window = NSApp.keyWindow {
                        window.orderOut(nil)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Contenido del prompt
            ScrollView {
                Text(prompt.content)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 10)
        .onAppear {
            // Optimización: Asegurar visibilidad y foco
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

#Preview {
    let samplePrompt = Prompt(
        title: "Code Review",
        content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Arquitectura y diseño\n2. Buenas prácticas\n3. Performance\n4. Seguridad\n\n{{codigo}}",
        folder: nil
    )
    
    PromptPreviewView(prompt: samplePrompt)
}
