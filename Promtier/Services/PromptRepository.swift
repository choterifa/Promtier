import Foundation
import CoreData
import SwiftUI

final class PromptRepository {
    static let shared = PromptRepository()
    let dataController: DataController
    var onDataChanged: (() -> Void)?
    
    init(dataController: DataController = .shared) {
        self.dataController = dataController
    }
    
    func removeDuplicatePrompts() {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        
        do {
            let allEntities = try context.fetch(request)
            var seenIds = Set<UUID>()
            var deletedCount = 0
            
            for entity in allEntities {
                if seenIds.contains(entity.id) {
                    context.delete(entity)
                    deletedCount += 1
                } else {
                    seenIds.insert(entity.id)
                }
            }
            
            if deletedCount > 0 {
                try context.save()
                print("🧹 Se eliminaron \(deletedCount) prompts duplicados de la base de datos.")
            }
        } catch {
            print("Error limpiando duplicados: \(error)")
        }
    }

    func migrateShowcaseImageCountIfNeeded() {
        let key = "hasMigratedShowcaseImageCountV1"
        if UserDefaults.standard.bool(forKey: key) { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let context: NSManagedObjectContext = self.dataController.backgroundContext
            var didUpdate = false

            context.performAndWaitCompat {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "showcaseImageCount == 0 AND (image1 != nil OR image2 != nil OR image3 != nil)")

                do {
                    let entities = try context.fetch(request)
                    guard !entities.isEmpty else { return }

                    for entity in entities {
                        autoreleasepool {
                            var count = 0
                            if entity.image1 != nil { count += 1 }
                            if entity.image2 != nil { count += 1 }
                            if entity.image3 != nil { count += 1 }
                            entity.showcaseImageCount = Int16(count)
                        }
                    }
                    try context.save()
                    didUpdate = true
                } catch {
                    print("Error migrando showcaseImageCount: \(error)")
                }
            }

            UserDefaults.standard.set(true, forKey: key)
            if didUpdate {
                DispatchQueue.main.async { self.onDataChanged?() }
            }
        }
    }

    func migrateShowcaseBlobsToDiskIfNeeded() {
        let key = "hasMigratedShowcaseImagesToDiskV1"
        if UserDefaults.standard.bool(forKey: key) { return }

        // Ejecutar sin bloquear el arranque.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            let context: NSManagedObjectContext = self.dataController.backgroundContext

            context.performAndWaitCompat {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "(image1 != nil OR image2 != nil OR image3 != nil) AND (image1Path == nil AND image2Path == nil AND image3Path == nil)")

                do {
                    let entities = try context.fetch(request)
                    if entities.isEmpty {
                        UserDefaults.standard.set(true, forKey: key)
                        return
                    }

                    var processed = 0
                    for entity in entities {
                        autoreleasepool {
                            let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                            if !legacy.isEmpty {
                                self.applyShowcaseImages(legacy, to: entity, promptId: entity.id, clearExisting: true)
                            }
                            processed += 1
                        }

                        if processed % 25 == 0, context.hasChanges {
                            try context.save()
                        }
                    }

                    if context.hasChanges {
                        try context.save()
                    }

                    print("🧳 Migración imágenes a disco completada. Items: \(entities.count)")
                    UserDefaults.standard.set(true, forKey: key)
                    DispatchQueue.main.async { self.onDataChanged?() }
                } catch {
                    print("Error migrando imágenes a disco: \(error)")
                }
            }
        }
    }

    func repairMissingShowcaseReferencesIfNeeded() {
        let key = "hasRepairedMissingShowcaseReferencesV1"
        if UserDefaults.standard.bool(forKey: key) { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let context: NSManagedObjectContext = self.dataController.backgroundContext
            var didUpdate = false

            context.performAndWaitCompat {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "image1Path != nil OR image2Path != nil OR image3Path != nil")

                do {
                    let entities = try context.fetch(request)
                    for entity in entities {
                        let existingPaths = [entity.image1Path, entity.image2Path, entity.image3Path]
                        let validMask = existingPaths.map { path in
                            guard let path else { return false }
                            return ImageStore.shared.fileExists(relativePath: path)
                        }

                        guard validMask.contains(false) else { continue }

                        entity.image1Path = validMask.indices.contains(0) && validMask[0] ? entity.image1Path : nil
                        entity.image2Path = validMask.indices.contains(1) && validMask[1] ? entity.image2Path : nil
                        entity.image3Path = validMask.indices.contains(2) && validMask[2] ? entity.image3Path : nil

                        entity.thumb1 = validMask.indices.contains(0) && validMask[0] ? entity.thumb1 : nil
                        entity.thumb2 = validMask.indices.contains(1) && validMask[1] ? entity.thumb2 : nil
                        entity.thumb3 = validMask.indices.contains(2) && validMask[2] ? entity.thumb3 : nil

                        let remaining = [entity.image1Path, entity.image2Path, entity.image3Path].compactMap { $0 }.count
                        entity.showcaseImageCount = Int16(remaining)
                        didUpdate = true
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    print("Error reparando referencias de imágenes inexistentes: \(error)")
                }
            }

            UserDefaults.standard.set(true, forKey: key)
            if didUpdate {
                DispatchQueue.main.async { self.onDataChanged?() }
            }
        }
    }

    
    func loadShowcaseImages(
        from paths: [String],
        maxImages: Int = PromptService.ShowcaseImageLoadPolicy.runtimeMaxImages,
        maxTotalBytes: Int? = nil
    ) -> [Data] {
        guard !paths.isEmpty else { return [] }

        var loaded: [Data] = []
        loaded.reserveCapacity(min(paths.count, maxImages))

        var totalBytes = 0
        for relativePath in paths.prefix(maxImages) {
            guard let data = ImageStore.shared.loadData(relativePath: relativePath) else { continue }

            if let maxTotalBytes, totalBytes + data.count > maxTotalBytes {
                break
            }

            totalBytes += data.count
            loaded.append(data)
        }
        return loaded
    }

    func fetchPromptSummaries(trashDict: [String: Date]) -> Result<[Prompt], Error> {
        let context: NSManagedObjectContext = dataController.backgroundContext
        var prompts: [Prompt] = []
        var fetchError: Error? = nil

        context.performAndWaitCompat {
            do {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "useCount", ascending: false),
                    NSSortDescriptor(key: "modifiedAt", ascending: false)
                ]
                request.returnsObjectsAsFaults = true
                request.includesPropertyValues = true
                request.fetchBatchSize = 200

                let entities = try context.fetch(request)
                prompts.reserveCapacity(entities.count)
                for entity in entities {
                    autoreleasepool {
                        var prompt = entity.toPrompt()
                        // Aplicar la fecha de eliminación desde el diccionario de la papelera
                        if let trashDate = trashDict[entity.id.uuidString] {
                            prompt.deletedAt = trashDate
                        }
                        prompts.append(prompt)
                    }
                }
            } catch {
                fetchError = error
            }
        }

        if let fetchError = fetchError {
            return .failure(fetchError)
        }
        return .success(prompts)
    }

    func fetchPrompt(byId id: UUID, includeImages: Bool) async -> Prompt? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Prompt?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let context: NSManagedObjectContext = self.dataController.backgroundContext
                var result: Prompt? = nil

                context.performAndWaitCompat {
                    let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1

                    do {
                        guard let entity = try context.fetch(request).first else { return }
                        var p = entity.toPrompt()

                        if includeImages {
                            if !p.showcaseImagePaths.isEmpty {
                                p.showcaseImages = self.loadShowcaseImages(
                                    from: p.showcaseImagePaths,
                                    maxImages: PromptService.ShowcaseImageLoadPolicy.runtimeMaxImages,
                                    maxTotalBytes: PromptService.ShowcaseImageLoadPolicy.runtimeMaxTotalBytes
                                )
                                p.showcaseImageCount = max(Int(entity.showcaseImageCount), p.showcaseImages.count)
                            } else {
                                // Fallback legacy (antes de migración a disco)
                                let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                                p.showcaseImages = legacy
                                p.showcaseImageCount = legacy.count
                            }
                        } else {
                            p.showcaseImages = []
                            p.showcaseImageCount = Int(entity.showcaseImageCount)
                        }
                        result = p
                    } catch {
                        print("Error obteniendo prompt: \(error)")
                    }
                }

                continuation.resume(returning: result)
            }
        }
    }

    func fetchShowcaseImages(byId id: UUID) async -> [Data] {
        let full = await fetchPrompt(byId: id, includeImages: true)
        return full?.showcaseImages ?? []
    }

    func fetchShowcaseImagePaths(byId id: UUID) async -> [String] {
        let prompt = await fetchPrompt(byId: id, includeImages: false)
        if let paths = prompt?.showcaseImagePaths, !paths.isEmpty {
            return paths
        }

        // Fallback legacy: si aún hay blobs, migrar on-demand para que la UI no pierda imágenes.
        if (prompt?.showcaseImageCount ?? 0) > 0 {
            let images = await fetchShowcaseImages(byId: id)
            if !images.isEmpty {
                _ = await updateShowcaseImages(promptId: id, images: images)
                let refreshed = await fetchPrompt(byId: id, includeImages: false)
                return refreshed?.showcaseImagePaths ?? []
            }
        }

        return []
    }

    func updateShowcaseImages(promptId: UUID, images: [Data]) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                let context: NSManagedObjectContext = self.dataController.backgroundContext
                var ok = false
                var updatedPrompt: Prompt? = nil

                context.performAndWaitCompat {
                    let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", promptId as CVarArg)
                    request.fetchLimit = 1

                    do {
                        guard let entity = try context.fetch(request).first else { return }
                        self.applyShowcaseImages(images, to: entity, promptId: promptId, clearExisting: true)
                        entity.modifiedAt = Date()

                        try context.save()
                        updatedPrompt = entity.toPrompt()
                        ok = true
                    } catch {
                        print("Error actualizando imágenes de showcase: \(error)")
                    }
                }

                if ok, let updatedPrompt {
                    self.onDataChanged?()
                }
                continuation.resume(returning: ok)
            }
        }
    }

    func applyShowcaseImages(_ images: [Data], to entity: PromptEntity, promptId: UUID, clearExisting: Bool) {
        if clearExisting {
            ImageStore.shared.deleteAllImages(for: promptId)
        }

        // Reset fields
        entity.image1Path = nil
        entity.image2Path = nil
        entity.image3Path = nil
        entity.thumb1 = nil
        entity.thumb2 = nil
        entity.thumb3 = nil

        // Clear legacy blobs
        entity.image1 = nil
        entity.image2 = nil
        entity.image3 = nil

        let capped = Array(images.prefix(3))
        var savedPaths: [String] = []
        var thumbs: [Data] = []

        for (idx, data) in capped.enumerated() {
            if let saved = try? ImageStore.shared.saveShowcaseImage(imageData: data, promptId: promptId, slot: idx + 1) {
                savedPaths.append(saved.relativePath)
                thumbs.append(saved.thumbnailData)
            }
        }

        entity.image1Path = savedPaths.indices.contains(0) ? savedPaths[0] : nil
        entity.image2Path = savedPaths.indices.contains(1) ? savedPaths[1] : nil
        entity.image3Path = savedPaths.indices.contains(2) ? savedPaths[2] : nil

        entity.thumb1 = thumbs.indices.contains(0) ? thumbs[0] : nil
        entity.thumb2 = thumbs.indices.contains(1) ? thumbs[1] : nil
        entity.thumb3 = thumbs.indices.contains(2) ? thumbs[2] : nil

        entity.showcaseImageCount = Int16(savedPaths.count)
    }


    func purgeExpiredTrash() {
        let context = dataController.viewContext
        let request = PromptEntity.fetchAll(in: context)
        
        guard let entities = try? context.fetch(request) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        
        var purgedCount = 0
        for entity in entities {
            if let deletedAt = entity.deletedAt, deletedAt < cutoff {
                var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
                dict.removeValue(forKey: entity.id.uuidString)
                UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
                context.delete(entity)
                purgedCount += 1
            }
        }
        if purgedCount > 0 {
            dataController.save()
            print("🗑️ Purgados \(purgedCount) prompts expirados de la papelera.")
        }
    }

    // MARK: - Prompt CRUD

    func createPrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let entity = PromptEntity(context: context)
        entity.id = prompt.id
        entity.createdAt = prompt.createdAt
        entity.updateFromPrompt(prompt)
        applyShowcaseImages(prompt.showcaseImages, to: entity, promptId: prompt.id, clearExisting: true)
        dataController.save()
        return true
    }

    func updatePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return false }
        entity.updateFromPrompt(prompt)
        dataController.save()
        return true
    }

    /// Records usage metrics (last used, count) in the background to prevent main-thread stutters.
    func recordPromptUseBackground(promptId: UUID) {
        let context = dataController.backgroundContext
        context.perform {
            let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", promptId as CVarArg)
            request.fetchLimit = 1
            
            if let entity = try? context.fetch(request).first {
                entity.useCount += 1
                entity.lastUsedAt = Date()
                if context.hasChanges {
                    do {
                        try context.save()
                    } catch {
                        print("Error saving prompt usage in background: \(error)")
                    }
                }
            }
        }
    }

    /// Soft-delete: mueve a la papelera registrando la fecha en UserDefaults.
    func deletePrompt(withId id: UUID) -> Bool {
        var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
        dict[id.uuidString] = Date()
        UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
        return true
    }

    func deletePrompts(withIds ids: [UUID]) -> Bool {
        var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
        let now = Date()
        for id in ids { dict[id.uuidString] = now }
        UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
        return true
    }

    func movePrompts(withIds ids: [UUID], toFolder folderName: String?) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids.map { $0 as CVarArg })

        guard let entities = try? context.fetch(request) else { return false }
        for entity in entities {
            entity.folder = folderName
            entity.modifiedAt = Date()
        }
        dataController.save()
        return true
    }

    func markPromptsFavorite(withIds ids: [UUID]) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids.map { $0 as CVarArg })

        guard let entities = try? context.fetch(request) else { return false }
        for entity in entities {
            entity.isFavorite = true
            entity.modifiedAt = Date()
        }
        dataController.save()
        return true
    }

    func restorePrompt(withId id: UUID) -> Bool {
        var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
        dict.removeValue(forKey: id.uuidString)
        UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
        return true
    }

    func permanentlyDeletePrompt(withId id: UUID) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return false }
        ImageStore.shared.deleteAllImages(for: id)

        var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
        dict.removeValue(forKey: id.uuidString)
        UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)

        context.delete(entity)
        dataController.save()
        return true
    }

    // MARK: - Folder CRUD

    func reorderFolders(_ folders: [Folder]) {
        let ids = folders.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: "folderSortOrder")
    }

    func createFolder(_ folder: Folder) -> Bool {
        let context = dataController.viewContext
        _ = FolderEntity.create(from: folder, in: context)
        dataController.save()
        return true
    }

    func updateFolder(_ folder: Folder, oldName: String? = nil) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return false }
        entity.name = folder.name
        entity.color = folder.color
        entity.icon = folder.icon

        // Renombrar la carpeta en prompts existentes si el nombre cambió
        if let oldName = oldName, oldName != folder.name {
            let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
            promptRequest.predicate = NSPredicate(format: "folder == %@", oldName)
            if let promptEntities = try? context.fetch(promptRequest) {
                for promptEntity in promptEntities {
                    promptEntity.folder = folder.name
                }
            }
        }

        dataController.save()
        return true
    }

    func deleteFolder(withId id: UUID, name: String) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else { return false }

        // Desasignar prompts que pertenecían a esta carpeta
        let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        promptRequest.predicate = NSPredicate(format: "folder == %@", name)
        if let promptEntities = try? context.fetch(promptRequest) {
            for promptEntity in promptEntities { promptEntity.folder = nil }
        }

        context.delete(entity)
        dataController.save()
        return true
    }

    func fetchFolders(sortMode: PromptService.FolderSortMode) -> [Folder] {
        let request = FolderEntity.fetchAll(in: dataController.viewContext)
        guard let entities = try? dataController.viewContext.fetch(request) else { return [] }

        var folders = entities.map { $0.toFolder() }

        if let savedOrder = UserDefaults.standard.stringArray(forKey: "folderSortOrder"), !savedOrder.isEmpty {
            let newFolders = folders.filter { !savedOrder.contains($0.id.uuidString) }
                .sorted { $0.createdAt > $1.createdAt }
            let orderedFolders = savedOrder.compactMap { id in folders.first { $0.id.uuidString == id } }
            folders = newFolders + orderedFolders
        } else {
            switch sortMode {
            case .name:    folders.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            case .newest:  folders.sort { $0.createdAt > $1.createdAt }
            }
        }

        return folders
    }

    // MARK: - Reset

    func resetAllData(dataController: DataController) {
        let context = dataController.viewContext
        ImageStore.shared.wipeAll()

        let promptRequest: NSFetchRequest<NSFetchRequestResult> = PromptEntity.fetchRequest()
        let folderRequest: NSFetchRequest<NSFetchRequestResult> = FolderEntity.fetchRequest()

        try? context.execute(NSBatchDeleteRequest(fetchRequest: promptRequest))
        try? context.execute(NSBatchDeleteRequest(fetchRequest: folderRequest))

        ["hasSeededDefaultsV28", "hasSeededInitialPromptsV28",
         "hasMigratedShowcaseImagesToDiskV1", "hasMigratedShowcaseImageCountV1"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }

        dataController.save()
    }
}
