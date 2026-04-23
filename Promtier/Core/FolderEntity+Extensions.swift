//
//  FolderEntity+Extensions.swift
//  Promtier
//
//  EXTENSIÓN: Lógica de mapeo y operaciones para FolderEntity
//

import Foundation
import CoreData

extension FolderEntity {
    
    /// Convierte una entidad de Core Data al modelo Folder de Swift
    func toFolder() -> Folder {
        return Folder(
            id: self.id,
            name: self.name,
            color: self.color,
            icon: self.icon,
            createdAt: self.createdAt,
            parentId: self.parentId
        )
    }
    
    /// Actualiza una entidad desde un modelo Folder
    func updateFromFolder(_ folder: Folder) {
        self.id = folder.id
        self.name = folder.name
        self.color = folder.color
        self.icon = folder.icon
        self.parentId = folder.parentId
        self.createdAt = folder.createdAt
    }
    
    /// Crea una nueva entidad desde un modelo Folder
    static func create(from folder: Folder, in context: NSManagedObjectContext) -> FolderEntity {
        let entity = FolderEntity(context: context)
        entity.updateFromFolder(folder)
        return entity
    }
    
    /// Petición para obtener todas las carpetas ordenadas
    static func fetchAll(in context: NSManagedObjectContext) -> NSFetchRequest<FolderEntity> {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.fetchBatchSize = 50 // Carpetas pueden ser más sin afectar RAM
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FolderEntity.name, ascending: true)]
        return request
    }
}
