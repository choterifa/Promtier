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
    
    let icons = [
        // Inteligencia Artificial y Pensamiento
        "brain.fill", "sparkles", "bolt.fill", "lightbulb.fill", "brain.headlight.fill",
        "cpu.fill", "network", "wand.and.stars.inverse", "bolt.shield.fill", "atom",
        "waveform.path.ecg.rectangle.fill", "square.stack.3d.up.fill", "bolt.square.fill", "sparkle",
        "brain.headlight.inverse", "bolt.horizontal.circle.fill", "wand.and.rays",

        // Escritura, Documentos y Creatividad
        "doc.text.fill", "pencil.and.outline", "paragraphsign", "text.quote", "signature",
        "book.closed.fill", "books.vertical.fill", "square.and.pencil", "doc.on.doc.fill",
        "list.bullet.indent", "character.bubble.fill", "fountainpen.tip", "doc.append.fill",
        "text.badge.plus", "quote.bubble.fill", "note.text", "doc.richtext.fill",
        "text.badge.checkmark", "doc.text.magnifyingglass", "character.cursor.ibeam",

        // Programación y Herramientas Técnicas
        "terminal.fill", "chevron.left.forwardslash.chevron.right", "curlybraces.square.fill",
        "command.circle.fill", "gearshape.2.fill", "hammer.circle.fill", "wrench.fill",
        "applescript.fill", "macwindow.badge.plus", "puzzlepiece.fill", "ant.fill",
        "memorychip.fill", "cpu", "command.square.fill", "shippingbox.fill",
        "hammer.fill", "wrench.and.screwdriver.fill", "curlybraces",

        // Marketing, Datos y Análisis
        "chart.bar.xaxis", "chart.line.uptrend.xyaxis.circle.fill", "target", "briefcase.fill",
        "magnifyingglass.circle.fill", "cube.transparent.fill", "dollarsign.circle.fill",
        "chart.pie.fill", "line.3.horizontal.decrease.circle.fill", "bag.fill", "cart.fill",
        "tag.fill", "bookmark.fill", "link", "timer", "stopwatch",
        "chart.xyaxis.line", "percent", "banknote.fill", "creditcard.fill",

        // Comunicación y Social
        "bubble.left.and.bubble.right.fill", "paperplane.fill", "megaphone.fill", "person.fill",
        "person.2.fill", "person.text.rectangle.fill", "message.and.waveform.fill",
        "envelope.badge.shield.half.filled.fill", "hand.thumbsup.fill", "heart.fill",
        "person.crop.circle.badge.checkmark", "at", "phone.circle.fill",
        "video.fill", "message.fill", "hand.raised.fill",

        // Multimedia, Diseño y Arte
        "photo.on.rectangle.angled.fill", "camera.aperture", "paintbrush.pointed.fill",
        "paintpalette.fill", "film.fill", "play.rectangle.on.rectangle.fill", "mic.badge.plus",
        "headphones", "video.and.waveform.fill", "scissors.circle.fill", "eye.fill",
        "circle.grid.cross.fill", "camera.fill", "music.note.list",
        "photo.fill", "play.circle.fill", "speaker.wave.2.fill",

        // General y Utilidades
        "star.bubble.fill", "flame.circle.fill", "flag.checkered.2.crossed", "bell.fill",
        "lock.fill", "lock.open.fill", "key.fill", "calendar.badge.clock", "map.fill",
        "gift.fill", "gamecontroller.fill", "trophy.fill", "medal.fill", "party.popper.fill",
        "exclamationmark.triangle.fill", "questionmark.circle.fill", "checkmark.seal.fill",
        "gavel.fill", "function", "globe.americas.fill", "leaf.fill",
        "house.fill", "airplane.circle.fill", "car.fill", "graduationcap.fill"
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
