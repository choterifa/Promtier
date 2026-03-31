//
//  IconPickerView.swift
//  Promtier
//
//  VISTA: Selector de iconos (SFSymbols) para prompts — Categorizado
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    let color: Color
    @EnvironmentObject var preferences: PreferencesManager
    
    // MARK: - Categorías de Iconos
    
    struct IconCategory: Identifiable {
        let id = UUID()
        let name: String
        let systemImage: String
        let icons: [String]
    }
    
    static let categories: [IconCategory] = [
        IconCategory(name: "IA & Pensamiento", systemImage: "brain", icons: [
            "brain.fill", "brain", "sparkles", "sparkle", "bolt.fill", "lightbulb.fill",
            "cpu.fill", "cpu", "network", "wand.and.stars", "atom",
            "bolt.horizontal.fill", "bolt.circle", "bolt.square.fill",
            "memorychip.fill"
        ]),
        IconCategory(name: "Programación", systemImage: "terminal.fill", icons: [
            "terminal.fill", "chevron.left.forwardslash.chevron.right", "curlybraces.square.fill",
            "curlybraces", "command.circle.fill", "command.square.fill",
            "applescript", "macwindow", "ant.fill",
            "hammer.fill", "hammer", "wrench.fill", "wrench.and.screwdriver.fill",
            "wrench.and.screwdriver", "gearshape.fill", "gear",
            "gearshape.2.fill", "puzzlepiece.fill", "shippingbox.fill", "shippingbox",
            "laptopcomputer", "desktopcomputer"
        ]),
        IconCategory(name: "Escritura & Docs", systemImage: "doc.text.fill", icons: [
            "doc.text.fill", "doc.text", "pencil.and.outline", "pencil.tip",
            "paragraphsign", "text.quote", "signature",
            "book.closed.fill", "books.vertical.fill", "square.and.pencil",
            "doc.on.doc.fill", "doc.append.fill", "doc.append",
            "list.bullet.indent", "character.bubble.fill",
            "text.badge.plus", "quote.bubble.fill", "note.text", "note",
            "doc.richtext.fill", "text.badge.checkmark",
            "doc.text.magnifyingglass", "character.cursor.ibeam",
            "doc.on.clipboard.fill"
        ]),
        IconCategory(name: "Negocios & Datos", systemImage: "chart.bar.fill", icons: [
            "chart.line.uptrend.xyaxis", "chart.bar.fill", "chart.pie.fill", "chart.pie",
            "chart.bar.xaxis", "target", "briefcase.fill",
            "magnifyingglass.circle.fill", "magnifyingglass",
            "dollarsign.circle.fill", "dollarsign.circle",
            "bag.fill", "bag", "cart.fill", "cart",
            "tag.fill", "bookmark.fill", "link", "timer", "stopwatch",
            "percent", "banknote.fill", "banknote", "creditcard.fill", "creditcard",
            "wallet.pass.fill"
        ]),
        IconCategory(name: "Comunicación", systemImage: "bubble.left.and.bubble.right.fill", icons: [
            "bubble.left.and.bubble.right.fill", "paperplane.fill",
            "megaphone.fill", "person.fill", "person.2.fill",
            "person.text.rectangle.fill", "envelope.fill",
            "hand.thumbsup.fill", "heart.fill", "heart.circle.fill",
            "person.crop.circle.badge.checkmark", "at",
            "phone.circle.fill", "message.fill", "hand.raised.fill"
        ]),
        IconCategory(name: "Multimedia & Arte", systemImage: "paintpalette.fill", icons: [
            "photo.on.rectangle.angled.fill", "photo.fill", "photo.artframe",
            "camera.aperture", "camera.fill", "camera",
            "paintbrush.pointed.fill", "paintbrush.fill", "paintpalette.fill",
            "film.fill", "play.rectangle.on.rectangle.fill",
            "mic.badge.plus", "mic.fill", "mic.circle.fill",
            "headphones", "video.fill", "scissors", "eye.fill",
            "circle.grid.cross", "music.note", "music.mic",
            "play.circle.fill", "play.fill", "speaker.wave.2.fill"
        ]),
        IconCategory(name: "General & Utilidad", systemImage: "star.fill", icons: [
            "star.fill", "star.circle.fill", "flame.fill", "flame",
            "flag.fill", "flag.circle.fill", "bell.fill", "bell.circle.fill",
            "lock.fill", "lock.open.fill", "key.fill",
            "calendar.badge.clock", "calendar", "calendar.badge.plus",
            "map.fill", "location.fill", "gift.fill", "gift",
            "gamecontroller.fill", "trophy.fill", "medal.fill", "party.popper.fill",
            "exclamationmark.triangle.fill", "questionmark.circle.fill",
            "checkmark.seal.fill", "shield.fill", "shield",
            "function", "globe.americas.fill", "globe", "leaf.fill",
            "house.fill", "airplane.circle.fill", "car.fill", "graduationcap.fill",
            "sun.max.fill", "moon.fill", "cloud.fill", "drop.fill",
            "flashlight.on.fill", "waveform.path.ecg",
            "folder", "folder.badge.plus", "archivebox", "archivebox.fill",
            "trash", "paperclip", "clock.fill", "alarm.fill",
            "square.and.arrow.up", "square.and.arrow.down",
            "cube.transparent.fill", "square.stack.3d.up.fill",
            "slider.horizontal.3", "slider.vertical.3",
            "ruler.fill", "stopwatch.fill"
        ])
    ]
    
    /// Lista plana de TODOS los iconos disponibles (para validar la selección IA)
    static var allIconNames: [String] {
        categories.flatMap { $0.icons }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("choose_icon".localized(for: preferences.language))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("done".localized(for: preferences.language)) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 4)
            
            // Opción por defecto (Carpeta)
            Button(action: {
                withAnimation(.spring()) { selectedIcon = nil }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(selectedIcon == nil ? color : .secondary)
                    Text("use_category_icon_help".localized(for: preferences.language))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedIcon == nil ? color : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(selectedIcon == nil ? color.opacity(0.12) : Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedIcon == nil ? color.opacity(0.3) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            // Categorías con iconos
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.categories) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            // Título de categoría
                            HStack(spacing: 4) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(category.name.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                            }
                            .padding(.leading, 2)
                            
                            // Grid de iconos
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 6) {
                                ForEach(category.icons, id: \.self) { icon in
                                    Button(action: {
                                        withAnimation(.spring()) { selectedIcon = icon }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                                .frame(width: 34, height: 34)
                                            
                                            Image(systemName: icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(selectedIcon == icon ? color : .primary.opacity(0.7))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .frame(width: 320, height: 460)
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("sparkles"), color: .blue)
        .padding()
}
