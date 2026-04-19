//
//  Theme.swift
//  Promtier
//
//  Design System: Constantes, colores y configuraciones globales
//

import SwiftUI

struct Theme {
    struct Colors {
        // Colores predefinidos de categorías
        static let presetCategoryColors: [(name: String, color: Color, emoji: String)] = [
            ("Azul", .blue, "🔵"), ("Morado", .purple, "🟣"), ("Rosa", .pink, "🩷"), ("Rojo", .red, "🔴"), 
            ("Naranja", .orange, "🟠"), ("Amarillo", .yellow, "🟡"), ("Verde", .green, "🟢"), 
            ("Menta", .mint, "🍃"), ("Cian", .cyan, "🩵"), ("Gris", .gray, "⚪️")
        ]
    }
    
    struct Icons {
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
        
        static var allIconNames: [String] {
            categories.flatMap { $0.icons }
        }
        
        static let spanishKeywords: [String: [String]] = [
            "cerebro": ["brain"], "ia": ["sparkle", "brain", "bolt"], "magia": ["sparkle", "wand"],
            "codigo": ["terminal", "curlybraces", "chevron"], "terminal": ["terminal", "command"],
            "herramienta": ["hammer", "wrench"], "ajustes": ["gear", "slider"], "configuracion": ["gear", "slider"],
            "archivo": ["doc", "folder", "archivebox"], "nota": ["note", "pencil", "signature"], "texto": ["doc.text", "paragraph", "quote"],
            "dinero": ["dollar", "banknote", "creditcard", "wallet"], "compras": ["cart", "bag", "tag"], "negocio": ["briefcase", "chart"],
            "persona": ["person"], "usuario": ["person"], "mensaje": ["bubble", "message", "envelope", "paperplane"], "correo": ["envelope", "at"],
            "foto": ["photo", "camera"], "imagen": ["photo", "camera"], "video": ["film", "video", "play"], "musica": ["music", "headphones", "speaker"],
            "juego": ["gamecontroller"], "trofeo": ["trophy", "medal"], "premio": ["gift"],
            "casa": ["house"], "mundo": ["globe", "map"], "ubicacion": ["location", "map"],
            "estrella": ["star"], "favorito": ["star", "heart"], "basura": ["trash"], "eliminar": ["trash", "xmark"],
            "reloj": ["clock", "timer", "stopwatch"], "calendario": ["calendar"], "tiempo": ["clock", "timer"],
            "alerta": ["exclamationmark", "bell"], "seguridad": ["lock", "shield", "key"],
            "computadora": ["laptop", "desktop"], "mac": ["macwindow", "laptop"]
        ]
    }
}