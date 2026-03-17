//
//  PromptEntity.swift
//  Promtier
//

import Foundation
import CoreData

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
    @NSManaged public var lastUsedAt: Date?
    @NSManaged public var icon: String?
    @NSManaged public var image1: Data?
    @NSManaged public var image2: Data?
    @NSManaged public var image3: Data?
    @NSManaged public var versionHistoryData: Data?

}
