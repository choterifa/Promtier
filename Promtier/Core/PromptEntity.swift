//
//  PromptEntity.swift
//  Promtier
//
//  ENTIDAD CORE DATA: Representación de Prompt en base de datos
//  Created by Carlos on 15/03/26.
//

import Foundation
import CoreData

// ENTIDAD CORE DATA: Clase generada para PromptEntity
@objc(PromptEntity)
public class PromptEntity: NSManagedObject {
    
}

extension PromptEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PromptEntity> {
        return NSFetchRequest<PromptEntity>(entityName: "PromptEntity")
    }
    
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var isFavorite: Bool
    @NSManaged public var modifiedAt: Date
    @NSManaged public var title: String
    @NSManaged public var useCount: Int32
    @NSManaged public var promptDescription: String?
    @NSManaged public var folder: String?
    @NSManaged public var tags: [String]?
    
}
