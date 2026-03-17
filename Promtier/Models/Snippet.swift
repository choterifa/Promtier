//
//  Snippet.swift
//  Promtier
//
//  MODELO: Fragmentos de texto reutilizables (Premium)
//

import Foundation

struct Snippet: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var shortcut: String // Comando para invocarlo (ej: "firma")
    var createdAt: Date = Date()
    
    init(title: String, content: String, shortcut: String) {
        self.title = title
        self.content = content
        self.shortcut = shortcut
    }
}
