//
//  PromptEntity+Extensions.swift
//  Promtier
//
//  EXTENSIÓN: Convierte entre Core Data y modelos Swift
//  Created by Carlos on 15/03/26.
//

import Foundation
import CoreData

private struct StoredAlternativeItem: Codable {
    let prompt: String
    let description: String?
}



// IMPORTAR MODELOS PARA CONVERSIÓN
// Nota: Este archivo necesita acceso a los modelos de datos

// EXTENSIÓN: Conversión entre entidades Core Data y modelos Swift
extension PromptEntity {
    
    /// Convierte entidad de Core Data a modelo Swift
    func toPrompt() -> Prompt {
        var prompt = Prompt(
            title: title,
            content: content,
            folder: folder
        )
        prompt.id = id
        prompt.isFavorite = isFavorite
        prompt.createdAt = createdAt
        prompt.modifiedAt = modifiedAt
        prompt.useCount = Int(useCount)
        prompt.lastUsedAt = lastUsedAt
        prompt.icon = icon
        prompt.promptDescription = promptDescription
        prompt.deletedAt = deletedAt
        prompt.negativePrompt = negativePrompt
        prompt.alternativePrompt = alternativePrompt
        prompt.customShortcut = customShortcut
        prompt.targetAppBundleIDs = targetAppBundleIDs
        prompt.parentID = parentID
        
        if let altData = alternativesData,
           let items = try? JSONDecoder().decode([StoredAlternativeItem].self, from: altData) {
            prompt.alternatives = items.map { $0.prompt }
            prompt.alternativeDescriptions = items.map { ($0.description ?? "") }
        } else if let altData = alternativesData,
                  let alts = try? JSONDecoder().decode([String].self, from: altData) {
            prompt.alternatives = alts
            prompt.alternativeDescriptions = Array(repeating: "", count: alts.count)
        } else {
            prompt.alternatives = []
            prompt.alternativeDescriptions = []
        }

        // Nuevo esquema: paths + thumbnails en Core Data (las imágenes completas viven en disco).
        let storedPaths = [image1Path, image2Path, image3Path]
        let storedThumbs = [thumb1, thumb2, thumb3]
        var validPaths: [String] = []
        var validThumbs: [Data] = []

        for index in storedPaths.indices {
            guard let path = storedPaths[index], !path.isEmpty else { continue }
            validPaths.append(path)
            if let thumb = storedThumbs[index] {
                validThumbs.append(thumb)
            }
        }

        prompt.showcaseImagePaths = validPaths
        prompt.showcaseThumbnails = validThumbs
        prompt.showcaseImages = [] // Lazy-load cuando se necesite

        // Mantener conteo consistente incluso si aún no se migró.
        let storedCount = Int(showcaseImageCount)
        if !prompt.showcaseImagePaths.isEmpty {
            prompt.showcaseImageCount = prompt.showcaseImagePaths.count
        } else if storedCount > 0 {
            // Mantener el conteo para permitir fallback lazy (fetch/migración on-demand).
            prompt.showcaseImageCount = storedCount
        } else {
            // Fallback legacy (antes de migración a disco)
            let legacyCount = [image1, image2, image3].compactMap { $0 }.count
            prompt.showcaseImageCount = legacyCount
        }
        
        if let historyData = versionHistoryData,
           let history = try? JSONDecoder().decode([PromptSnapshot].self, from: historyData) {
            prompt.versionHistory = history
        }
        
        return prompt
    }
    
    
    /// Actualiza entidad desde modelo Swift
    func updateFromPrompt(_ prompt: Prompt) {
        title = prompt.title
        content = prompt.content
        folder = prompt.folder
        icon = prompt.icon
        promptDescription = prompt.promptDescription
        deletedAt = prompt.deletedAt
        negativePrompt = prompt.negativePrompt
        alternativePrompt = prompt.alternativePrompt
        customShortcut = prompt.customShortcut
        targetAppBundleIDs = prompt.targetAppBundleIDs
        parentID = prompt.parentID
        
        let descriptions = Array(prompt.alternativeDescriptions.prefix(prompt.alternatives.count))
        let items = prompt.alternatives.enumerated().map { index, text in
            StoredAlternativeItem(prompt: text, description: index < descriptions.count ? descriptions[index] : nil)
        }

        if let altData = try? JSONEncoder().encode(items) {
            alternativesData = altData
        } else if let altData = try? JSONEncoder().encode(prompt.alternatives) {
            // Fallback defensivo en caso de fallo serializando la estructura nueva
            alternativesData = altData
        }

        // NOTA: Las imágenes ahora se guardan en disco (ImageStore).
        // Este método solo actualiza conteo cuando el caller provee imágenes explícitas.
        // La asignación de paths/thumbs se maneja desde PromptService.
        if !prompt.showcaseImages.isEmpty || prompt.showcaseImageCount == 0 {
            showcaseImageCount = Int16(min(prompt.showcaseImages.count, 3))
        }
        
        isFavorite = prompt.isFavorite
        useCount = Int32(prompt.useCount)
        modifiedAt = prompt.modifiedAt
        lastUsedAt = prompt.lastUsedAt
        
        // Sincronizar campo legacy con el primer elemento para retrocompatibilidad
        alternativePrompt = prompt.alternatives.first
        
        if let historyData = try? JSONEncoder().encode(prompt.versionHistory) {
            versionHistoryData = historyData
        }
    }
    
    /// Crea nueva entidad desde modelo Swift
    static func create(from prompt: Prompt, in context: NSManagedObjectContext) -> PromptEntity {
        let entity = PromptEntity(context: context)
        entity.id = prompt.id
        entity.createdAt = prompt.createdAt
        entity.updateFromPrompt(prompt)
        return entity
    }
}



// EXTENSIÓN: Consultas predefinidas para PromptEntity
extension PromptEntity {
    
    /// Obtiene todos los prompts ordenados por uso
    static func fetchAll(in context: NSManagedObjectContext) -> NSFetchRequest<PromptEntity> {
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        
        // Optimización de Memoria (Evitar picos de RAM cargando demasiadas entidades)
        request.fetchBatchSize = 25
        
        // CONFIGURABLE: Ordenamiento por defecto
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PromptEntity.useCount, ascending: false),
            NSSortDescriptor(keyPath: \PromptEntity.modifiedAt, ascending: false)
        ]
        
        return request
    }
    
    /// Busca prompts por texto en título, contenido o etiquetas
    static func searchPrompts(query: String, in context: NSManagedObjectContext) -> NSFetchRequest<PromptEntity> {
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.fetchBatchSize = 25
        
        if query.isEmpty {
            return fetchAll(in: context)
        }
        
        // CONFIGURABLE: Búsqueda en múltiples campos
        let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
        let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
        
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            titlePredicate,
            contentPredicate
        ])
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PromptEntity.useCount, ascending: false),
            NSSortDescriptor(keyPath: \PromptEntity.modifiedAt, ascending: false)
        ]
        
        // CONFIGURABLE: Límite de resultados de búsqueda
        request.fetchLimit = 50
        
        return request
    }
    
    /// Obtiene solo los favoritos
    static func fetchFavorites(in context: NSManagedObjectContext) -> NSFetchRequest<PromptEntity> {
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.fetchBatchSize = 25
        request.predicate = NSPredicate(format: "isFavorite == YES")
        
        // CONFIGURABLE: Ordenamiento de favoritos
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PromptEntity.useCount, ascending: false),
            NSSortDescriptor(keyPath: \PromptEntity.modifiedAt, ascending: false)
        ]
        
        return request
    }
}
