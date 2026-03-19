//
//  PromptEntity+Extensions.swift
//  Promtier
//
//  EXTENSIÓN: Convierte entre Core Data y modelos Swift
//  Created by Carlos on 15/03/26.
//

import Foundation
import CoreData



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
        
        if let altData = alternativesData,
           let alts = try? JSONDecoder().decode([String].self, from: altData) {
            prompt.alternatives = alts
        } else {
            prompt.alternatives = []
        }

        // Nuevo esquema: paths + thumbnails en Core Data (las imágenes completas viven en disco).
        prompt.showcaseImagePaths = [image1Path, image2Path, image3Path].compactMap { $0 }
        prompt.showcaseThumbnails = [thumb1, thumb2, thumb3].compactMap { $0 }
        prompt.showcaseImages = [] // Lazy-load cuando se necesite

        // Mantener conteo consistente incluso si aún no se migró.
        let storedCount = Int(showcaseImageCount)
        if storedCount > 0 {
            prompt.showcaseImageCount = storedCount
        } else if !prompt.showcaseImagePaths.isEmpty {
            prompt.showcaseImageCount = prompt.showcaseImagePaths.count
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
        
        if let altData = try? JSONEncoder().encode(prompt.alternatives) {
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
        request.predicate = NSPredicate(format: "isFavorite == YES")
        
        // CONFIGURABLE: Ordenamiento de favoritos
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \PromptEntity.useCount, ascending: false),
            NSSortDescriptor(keyPath: \PromptEntity.modifiedAt, ascending: false)
        ]
        
        return request
    }
}
