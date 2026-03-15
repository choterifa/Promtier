//
//  Folder.swift
//  Promtier
//
//  MODELO DE CARPETA: Organización jerárquica de prompts
//  Created by Carlos on 15/03/26.
//

import Foundation

// MODELO DE CARPETA: Organización jerárquica
struct Folder: Identifiable, Codable, Hashable {
    let id: UUID                    // Identificador único
    var name: String                // Nombre de carpeta
    var color: String?              // Color opcional (hex)
    var createdAt: Date              // Fecha de creación
    var parentId: UUID?             // ID de carpeta padre para anidación
    
    // Inicializador con valores por defecto
    init(name: String, color: String? = nil, parentId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdAt = Date()
        self.parentId = parentId
    }
    
    // MARK: - Métodos de ayuda
    
    /// Verifica si es una carpeta raíz (no tiene padre)
    var isRoot: Bool {
        return parentId == nil
    }
    
    /// Retorna el color hex o un color por defecto
    var displayColor: String {
        return color ?? "#007AFF" // CONFIGURABLE: Color por defecto de carpetas
    }
}
