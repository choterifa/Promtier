//
//  FolderEntity.swift
//  Promtier
//

import Foundation
import CoreData

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
    @NSManaged public var icon: String?
    
}
