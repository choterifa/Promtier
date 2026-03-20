//
//  PromptEntity.swift
//  Promtier
//

import Foundation
import CoreData

@objc(PromptEntity)
public class PromptEntity: NSManagedObject {
    
    // MARK: - Soft Delete (Papelera)
    // Guardado en UserDefaults para evitar migración del schema
    static let trashKey = "promptTrashDates"
    
    var deletedAt: Date? {
        get {
            let dict = UserDefaults.standard.dictionary(forKey: Self.trashKey) as? [String: Date] ?? [:]
            return dict[id.uuidString]
        }
        set {
            var dict = UserDefaults.standard.dictionary(forKey: Self.trashKey) as? [String: Date] ?? [:]
            if let date = newValue {
                dict[id.uuidString] = date
            } else {
                dict.removeValue(forKey: id.uuidString)
            }
            UserDefaults.standard.set(dict, forKey: Self.trashKey)
        }
    }
    
    // MARK: - App Associations
    static let appAssociationsKey = "promptAppAssociations"
    
    var targetAppBundleIDs: [String] {
        get {
            let dict = UserDefaults.standard.dictionary(forKey: Self.appAssociationsKey) as? [String: [String]] ?? [:]
            return dict[id.uuidString] ?? []
        }
        set {
            var dict = UserDefaults.standard.dictionary(forKey: Self.appAssociationsKey) as? [String: [String]] ?? [:]
            if newValue.isEmpty {
                dict.removeValue(forKey: id.uuidString)
            } else {
                dict[id.uuidString] = newValue
            }
            UserDefaults.standard.set(dict, forKey: Self.appAssociationsKey)
        }
    }
    
    // MARK: - Branching (Linking)
    static let parentIDsKey = "promptParentIDs"
    var parentID: UUID? {
        get {
            let dict = UserDefaults.standard.dictionary(forKey: Self.parentIDsKey) as? [String: String] ?? [:]
            if let uuidString = dict[id.uuidString] {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            var dict = UserDefaults.standard.dictionary(forKey: Self.parentIDsKey) as? [String: String] ?? [:]
            if let uuid = newValue {
                dict[id.uuidString] = uuid.uuidString
            } else {
                dict.removeValue(forKey: id.uuidString)
            }
            UserDefaults.standard.set(dict, forKey: Self.parentIDsKey)
        }
    }
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
    @NSManaged public var image1Path: String?
    @NSManaged public var image2Path: String?
    @NSManaged public var image3Path: String?
    @NSManaged public var thumb1: Data?
    @NSManaged public var thumb2: Data?
    @NSManaged public var thumb3: Data?
    @NSManaged public var showcaseImageCount: Int16
    @NSManaged public var versionHistoryData: Data?
    @NSManaged public var negativePrompt: String?
    @NSManaged public var alternativePrompt: String?
    @NSManaged public var customShortcut: String?
    @NSManaged public var alternativesData: Data?

}
