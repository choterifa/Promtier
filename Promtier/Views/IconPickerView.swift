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
    @EnvironmentObject var preferences: PreferencesManager
    
    // Lista curada de iconos útiles para prompts de IA
    let icons = [
        // AI / Inteligencia / Creatividad
        "cpu", "sparkles", "sparkle", "bolt.fill", "bulb",
        "wand.and.stars", "face.smiling", "eyes", "brain", "atom", "magicmouse.fill",
        "square.stack.3d.up.fill", "icloud.and.arrow.down", "network", "waveform.path.ecg", "antenna.radiowaves.left.and.right",

        // Escritura / Documentos / Notas
        "doc.text.fill", "pencil.tip.crop.circle", "keyboard", "text.quote", "signature",
        "book.fill", "books.vertical.fill", "square.and.pencil", "doc.plaintext.fill", "list.bullet.rectangle",
        "character.cursor.ibeam", "text.justify.left", "doc.plaintext", "text.bubble.fill", "note.text", "doc.richtext.fill",

        // Código / Desarrollo / Terminal
        "terminal.fill", "command", "curlybraces", "chevron.left.forwardslash.chevron.right", "gearshape.fill",
        "hammer.fill", "wrench.and.screwdriver.fill", "macwindow", "scroll.fill",
        "arrow.left.and.right", "app.badge.fill", "laptopcomputer", "puzzlepiece.fill", "ant.fill", "externaldrive.fill", "memorychip", "case.fill",

        // Comunicación / Redacción / Social
        "bubble.left.and.bubble.right.fill", "envelope.fill", "paperplane.fill", "megaphone.fill", "person.fill",
        "person.2.fill", "person.3.fill", "person.text.rectangle.fill", "phone.fill",
        "video.fill", "message.fill", "hand.thumbsup.fill", "quote.bubble.fill",

        // Análisis / Datos / Negocios / Finanzas
        "chart.bar.fill", "magnifyingglass", "cube.fill", "square.stack.3d.up.fill", "target",
        "briefcase.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill", "eurosign.circle.fill", "cart.fill", "bag.fill",
        "line.diagonal", "slider.horizontal.3", "timer", "stopwatch.fill",

        // Multimedia / Diseño / Arte
        "photo.fill", "camera.fill", "paintbrush.fill", "paintpalette.fill", "film.fill",
        "play.fill", "music.note", "music.mic", "speaker.wave.3.fill", "mic.fill", "headphones",
        "crop", "perspective", "scissors", "metronome.fill",

        // Ciencia / Naturaleza / Educación
        "leaf.fill", "drop.fill", "sun.max.fill", "moon.fill", "cloud.fill",
        "thermometer.medium", "flask.fill", "testtube.2", "graduationcap.fill",
        "globe.americas.fill", "mountain.2.fill", "ruler.fill", "pills.fill", "medical.thermometer.fill",

        // General / Otros
        "gift.fill", "gamecontroller.fill", "die.face.5.fill", "cup.and.saucer.fill",
        "fork.knife", "trophy.fill", "medal.fill", "flag.fill", "bell.fill", "flame.fill", "bicycle", "airplane",
        "key.fill", "lock.fill", "calendar", "map.fill", "star.fill", "party.popper.fill"
    ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("choose_icon".localized(for: preferences.language))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                // El botón de aceptar que pidió el usuario
                Button("done".localized(for: preferences.language)) {
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
                    .help("use_category_icon_help".localized(for: preferences.language))
                    
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
            .frame(height: 300)
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
