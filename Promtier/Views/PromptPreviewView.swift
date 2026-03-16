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
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header estilo Quick Look
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(prompt.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Vista Previa")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            Divider()
            
            // Contenido con tipografía mejorada
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(prompt.content)
                        .font(.system(size: 14 * preferences.fontSize.scale, design: .monospaced))
                        .lineSpacing(6)
                        .foregroundColor(.primary.opacity(0.9))
                        .textSelection(.enabled)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow))
        }
        .frame(width: 480, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// Auxiliar para efectos de desenfoque nativos
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
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

#Preview {
    let samplePrompt = Prompt(
        title: "Code Review",
        content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Arquitectura y diseño\n2. Buenas prácticas\n3. Performance\n4. Seguridad\n\n{{codigo}}",
        folder: nil
    )
    
    PromptPreviewView(prompt: samplePrompt)
}
