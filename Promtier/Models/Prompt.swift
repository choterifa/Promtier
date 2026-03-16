//
//  Prompt.swift
//  Promtier
//
//  MODELO PRINCIPAL: Estructura de datos para cada prompt de IA
//  Created by Carlos on 15/03/26.
//

import Foundation

// MODELO PRINCIPAL: Estructura de datos para cada prompt
struct Prompt: Identifiable, Codable {
    var id: UUID                    // Identificador único
    var title: String               // Título del prompt
    var content: String             // Contenido del prompt
    var folder: String?             // Carpeta de organización
    var isFavorite: Bool            // Marcar como favorito
    var createdAt: Date              // Fecha de creación
    var modifiedAt: Date            // Fecha de modificación
    var useCount: Int               // Contador de uso
    var lastUsedAt: Date?           // Última vez que se copió
    var icon: String?                // Icono personalizado (SFSymbol)
    var showcaseImages: [Data] = []  // Imágenes de resultados (max 3)
    
    // Inicializador con valores por defecto
    init(title: String, content: String, folder: String? = nil, icon: String? = nil, showcaseImages: [Data] = []) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.folder = folder
        self.icon = icon
        self.showcaseImages = showcaseImages
        self.isFavorite = false
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.useCount = 0
    }
    
    // MARK: - Métodos de ayuda
    
    /// Incrementa el contador de uso del prompt
    mutating func recordUse() {
        useCount += 1
        lastUsedAt = Date()
        modifiedAt = Date()
    }
    
    /// Verifica si el prompt contiene variables de plantilla {{variable}}
    func hasTemplateVariables() -> Bool {
        let pattern = "\\{\\{[^}]+\\}\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex?.firstMatch(in: content, options: [], range: range) != nil
    }
    
    /// Extrae los nombres de las variables de plantilla del contenido
    func extractTemplateVariables() -> [String] {
        let pattern = "\\{\\{([^}]+)\\}\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        
        var variables: [String] = []
        regex?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            if let captureRange = match?.range(at: 1),
               let variableName = (content as NSString).substring(with: captureRange) as String? {
                // Limpiar espacios en blanco alrededor del nombre de la variable
                let trimmedName = variableName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty && !variables.contains(trimmedName) {
                    variables.append(trimmedName)
                }
            }
        }
        return variables
    }
}
