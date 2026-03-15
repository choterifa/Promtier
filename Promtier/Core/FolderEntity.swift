//
//  FolderEntity.swift
//  Promtier
//
//  ENTIDAD CORE DATA: Representación de Folder en base de datos
//  Created by Carlos on 15/03/26.
//

import Foundation
import CoreData

// ENTIDAD CORE DATA: Clase generada para FolderEntity
@objc(FolderEntity)
public class FolderEntity: NSManagedObject {
    
}

extension FolderEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FolderEntity> {
        return NSFetchRequest<FolderEntity>(entityName: "FolderEntity")
    }
    
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var parentId: UUID?
    
}
