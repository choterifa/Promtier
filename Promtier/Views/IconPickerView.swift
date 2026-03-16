//
//  IconPickerView.swift
//  Promtier
//
//  VISTA: Selector de iconos (SFSymbols) para prompts
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    let color: Color
    
    // Lista curada de iconos útiles para prompts de IA
    let icons = [
        // Inteligencia / Cerebro
        "cpu", "brain.head.profile", "lightbulb.fill", "sparkles", "bolt.fill",
        // Escritura / Documentos
        "doc.text.fill", "pencil.tip.crop.circle", "keyboard", "text.quote", "signature",
        // Código / Desarrollo
        "terminal.fill", "command", "curlybraces", "chevron.left.forwardslash.chevron.right", "gearshape.fill",
        // Comunicación / Redacción
        "bubble.left.and.bubble.right.fill", "envelope.fill", "paperplane.fill", "megaphone.fill", "person.fill",
        // Análisis / Datos
        "chart.bar.fill", "magnifyingglass", "cube.fill", "square.stack.3d.up.fill", "target",
        // Otros
        "gift.fill", "gamecontroller.fill", "music.note", "camera.fill", "bag.fill"
    ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Elegir Icono")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                // El botón de aceptar que pidió el usuario
                Button("Listo") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction) // Soporta la tecla ENTER
            }
            .padding(.horizontal, 4)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 38))], spacing: 12) {
                    // Opción por defecto (Icono de carpeta/categoría)
                    Button(action: { 
                        withAnimation(.spring()) { selectedIcon = nil }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIcon == nil ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                .frame(width: 38, height: 38)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 16))
                                .foregroundColor(selectedIcon == nil ? color : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Usar icono de categoría")
                    
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { 
                            withAnimation(.spring()) { selectedIcon = icon }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIcon == icon ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                    .frame(width: 38, height: 38)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedIcon == icon ? color : .primary.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            .frame(height: 200)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .frame(width: 300)
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("sparkles"), color: .blue)
        .padding()
}
