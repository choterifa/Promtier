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
        return prompt
    }
    
    
    /// Actualiza entidad desde modelo Swift
    func updateFromPrompt(_ prompt: Prompt) {
        title = prompt.title
        content = prompt.content
        folder = prompt.folder
        isFavorite = prompt.isFavorite
        useCount = Int32(prompt.useCount)
        modifiedAt = prompt.modifiedAt
        lastUsedAt = prompt.lastUsedAt
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
