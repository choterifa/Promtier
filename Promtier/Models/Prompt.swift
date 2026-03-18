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
    var promptDescription: String?  // Descripción breve opcional
    var folder: String?             // Carpeta de organización
    var isFavorite: Bool            // Marcar como favorito
    var createdAt: Date             // Fecha de creación
    var modifiedAt: Date            // Fecha de modificación
    var useCount: Int               // Contador de uso
    var lastUsedAt: Date?           // Última vez que se copió
    var icon: String?               // Icono personalizado (SFSymbol)
    var showcaseImages: [Data] = [] // Imágenes de resultados (max 3)
    /// Conteo persistido para UI/lista (permite lazy-load de blobs).
    var showcaseImageCount: Int = 0
    /// Paths relativos en disco (app support) para imágenes guardadas.
    var showcaseImagePaths: [String] = []
    /// Thumbnails (pequeños) para UI rápida.
    var showcaseThumbnails: [Data] = []
    var versionHistory: [PromptSnapshot] = [] // Historial de versiones (Premium)
    var tags: [String] = []         // Etiquetas (Premium)
    var deletedAt: Date? = nil      // Si tiene fecha, está en la papelera
    
    // Nuevas funciones de prompt
    var negativePrompt: String?     // Lo que la IA NO debe hacer
    var alternativePrompt: String?  // Un prompt similar o variante
    
    // Inicializador con valores por defecto
    init(title: String, content: String, promptDescription: String? = nil, folder: String? = nil, icon: String? = nil, showcaseImages: [Data] = [], tags: [String] = [], negativePrompt: String? = nil, alternativePrompt: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.promptDescription = promptDescription
        self.folder = folder
        self.icon = icon
        self.showcaseImages = Array(showcaseImages.prefix(3))
        self.showcaseImageCount = self.showcaseImages.count
        self.showcaseImagePaths = []
        self.showcaseThumbnails = []
        self.tags = tags
        self.negativePrompt = negativePrompt
        self.alternativePrompt = alternativePrompt
        self.isFavorite = false
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.useCount = 0
        self.deletedAt = nil
    }

    // MARK: - Codable (retrocompatible)
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case promptDescription
        case folder
        case isFavorite
        case createdAt
        case modifiedAt
        case useCount
        case lastUsedAt
        case icon
        case showcaseImages
        case showcaseImageCount
        case showcaseImagePaths
        case showcaseThumbnails
        case versionHistory
        case tags
        case deletedAt
        case negativePrompt
        case alternativePrompt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)

        promptDescription = try container.decodeIfPresent(String.self, forKey: .promptDescription)
        folder = try container.decodeIfPresent(String.self, forKey: .folder)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)

        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        showcaseImages = Array((try container.decodeIfPresent([Data].self, forKey: .showcaseImages) ?? []).prefix(3))

        let decodedCount = try container.decodeIfPresent(Int.self, forKey: .showcaseImageCount)
        showcaseImageCount = decodedCount ?? showcaseImages.count

        showcaseImagePaths = try container.decodeIfPresent([String].self, forKey: .showcaseImagePaths) ?? []
        showcaseThumbnails = try container.decodeIfPresent([Data].self, forKey: .showcaseThumbnails) ?? []

        versionHistory = try container.decodeIfPresent([PromptSnapshot].self, forKey: .versionHistory) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)

        negativePrompt = try container.decodeIfPresent(String.self, forKey: .negativePrompt)
        alternativePrompt = try container.decodeIfPresent(String.self, forKey: .alternativePrompt)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(promptDescription, forKey: .promptDescription)
        try container.encodeIfPresent(folder, forKey: .folder)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(useCount, forKey: .useCount)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(showcaseImages, forKey: .showcaseImages)
        try container.encode(showcaseImageCount, forKey: .showcaseImageCount)
        try container.encode(showcaseImagePaths, forKey: .showcaseImagePaths)
        try container.encode(showcaseThumbnails, forKey: .showcaseThumbnails)
        try container.encode(versionHistory, forKey: .versionHistory)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(negativePrompt, forKey: .negativePrompt)
        try container.encodeIfPresent(alternativePrompt, forKey: .alternativePrompt)
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
    
    /// True si está en la papelera
    var isInTrash: Bool { deletedAt != nil }
    
    /// True si fue eliminado hace menos de 7 días (aún recuperable)
    var canRestore: Bool {
        guard let d = deletedAt else { return false }
        return Date().timeIntervalSince(d) < 7 * 86400
    }
}

/// Representa una versión guardada de un prompt (Premium)
struct PromptSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let content: String
    let timestamp: Date
}
