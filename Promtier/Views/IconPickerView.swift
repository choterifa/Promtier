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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elegir Icono")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 35))], spacing: 10) {
                    // Opción por defecto (Icono de carpeta/categoría)
                    Button(action: { selectedIcon = nil }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIcon == nil ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                .frame(width: 35, height: 35)
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(selectedIcon == nil ? color : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Usar icono de categoría")
                    
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { selectedIcon = icon }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                    .frame(width: 35, height: 35)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedIcon == icon ? color : .primary.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .frame(width: 280)
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("sparkles"), color: .blue)
        .padding()
}
