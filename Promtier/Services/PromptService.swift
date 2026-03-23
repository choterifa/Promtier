//
//  PromptService.swift
//  Promtier
//
//  SERVICIO PRINCIPAL: CRUD, búsqueda y gestión de prompts
//  Created by Carlos on 15/03/26.
//

import Foundation
@preconcurrency import CoreData
import Combine

// SERVICIO PRINCIPAL: Gestión completa de prompts
class PromptService: ObservableObject {
    static let shared = PromptService()
    
    private let dataController = DataController.shared
    private let clipboardService = ClipboardService.shared
    
    // CONFIGURABLE: Publicación de cambios para UI reactiva
    @Published var prompts: [Prompt] = []
    @Published var filteredPrompts: [Prompt] = []
    @Published var trashedPrompts: [Prompt] = []
    @Published var folders: [Folder] = []
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String? = nil
    @Published var isLoading: Bool = false
    @Published var activeAppBundleID: String? = nil
    
    enum FolderSortMode: String, Codable, CaseIterable {
        case name
        case newest
    }
    
    @Published var folderSortMode: FolderSortMode = .name {
        didSet {
            UserDefaults.standard.set(folderSortMode.rawValue, forKey: "folderSortMode_preference")
            loadFolders()
        }
    }
    
    enum PromptSortMode: String, Codable, CaseIterable {
        case name
        case newest
        case mostUsed
    }
    
    @Published var promptSortMode: PromptSortMode = .newest {
        didSet {
            UserDefaults.standard.set(promptSortMode.rawValue, forKey: "promptSortMode_preference")
            filterPrompts(query: searchQuery)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observar cambios en búsqueda para filtrar automáticamente
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main) 
            .sink { [weak self] query in
                self?.filterPrompts(query: query)
            }
            .store(in: &cancellables)
            
        // Observar cambios en categoría para filtrar automáticamente
        $selectedCategory
            .sink { [weak self] category in
                self?.filterPrompts(query: self?.searchQuery ?? "", categoryOverride: category)
            }
            .store(in: &cancellables)
            
        if let savedMode = UserDefaults.standard.string(forKey: "folderSortMode_preference"),
           let mode = FolderSortMode(rawValue: savedMode) {
            self.folderSortMode = mode
        }
        
        if let savedMode = UserDefaults.standard.string(forKey: "promptSortMode_preference"),
           let mode = PromptSortMode(rawValue: savedMode) {
            self.promptSortMode = mode
        }
        
        seedDefaultFolders() // Crear categorías de sistema si no existen
        seedDefaultPrompts() // Crear prompts de ejemplo iniciales
        purgeExpiredTrash()  // Limpiar papelera de entradas > 7 días
        loadFolders()
        loadPrompts()
        migrateShowcaseImageCountIfNeeded()
        migrateShowcaseBlobsToDiskIfNeeded()
    }

    private func migrateShowcaseImageCountIfNeeded() {
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
                DispatchQueue.main.async { self.loadPrompts() }
            }
        }
    }

    private func migrateShowcaseBlobsToDiskIfNeeded() {
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
                    DispatchQueue.main.async { self.loadPrompts() }
                } catch {
                    print("Error migrando imágenes a disco: \(error)")
                }
            }
        }
    }
    
    /// Crea las carpetas por defecto si no han sido sembradas aún en esta versión
    private func seedDefaultFolders() {
        let context = dataController.viewContext
        
        // Usamos un flag de versión para asegurar que se siembren al menos una vez al actualizar
        let seedKey = "hasSeededDefaultsV25" // BUMP VERSION
        if UserDefaults.standard.bool(forKey: seedKey) { return }
        
        let request = FolderEntity.fetchAll(in: context)
        
        do {
            let entities = try context.fetch(request)
            let existingNames = entities.map { $0.name }
            
            print("🌱 Sembrando categorías base como guía...")
            var seededCount = 0
            
            for cat in PredefinedCategory.allCases {
                // Solo añadir si no existe ya una con ese nombre exacto
                if !existingNames.contains(cat.displayName) {
                    let folder = Folder(
                        id: UUID(),
                        name: cat.displayName,
                        color: cat.hexColor,
                        icon: cat.icon,
                        createdAt: Date(),
                        parentId: nil
                    )
                    _ = FolderEntity.create(from: folder, in: context)
                    seededCount += 1
                }
            }
            
            if seededCount > 0 {
                dataController.save()
                print("✅ \(seededCount) categorías base añadidas.")
            }
            
            UserDefaults.standard.set(true, forKey: seedKey)
            
        } catch {
            print("Error sembrando categorías: \(error)")
        }
    }
    
    /// Crea prompts de ejemplo para guiar al usuario
    private func seedDefaultPrompts() {
        let context = dataController.viewContext
        let seedKey = "hasSeededInitialPromptsV25" // BUMP VERSION
        if UserDefaults.standard.bool(forKey: seedKey) { return }
        
        print("🌱 Sembrando prompts de ejemplo realistas (V25)...")
        
        let language = PreferencesManager.shared.language
        
        // 1. ChatGPT - Brainstorming
        let chatGPTPrompt = Prompt(
            title: "default_prompt_chatgpt_title".localized(for: language),
            content: "default_prompt_chatgpt_content".localized(for: language),
            folder: PredefinedCategory.chatGPT.displayName,
            icon: PredefinedCategory.chatGPT.icon
        )
        _ = PromptEntity.create(from: chatGPTPrompt, in: context)
        
        // 2. Claude - Architecture
        let claudePrompt = Prompt(
            title: "default_prompt_claude_title".localized(for: language),
            content: "default_prompt_claude_content".localized(for: language),
            folder: PredefinedCategory.claude.displayName,
            icon: PredefinedCategory.claude.icon
        )
        _ = PromptEntity.create(from: claudePrompt, in: context)
        
        // 3. Cursor - Implementation
        let cursorPrompt = Prompt(
            title: "default_prompt_cursor_title".localized(for: language),
            content: "default_prompt_cursor_content".localized(for: language),
            folder: PredefinedCategory.cursor.displayName,
            icon: PredefinedCategory.cursor.icon
        )
        _ = PromptEntity.create(from: cursorPrompt, in: context)
        
        // 4. Midjourney - Art
        let midjourneyPrompt = Prompt(
            title: "default_prompt_midjourney_title".localized(for: language),
            content: "default_prompt_midjourney_content".localized(for: language),
            folder: PredefinedCategory.midjourney.displayName,
            icon: PredefinedCategory.midjourney.icon
        )
        _ = PromptEntity.create(from: midjourneyPrompt, in: context)
        
        // 5. Stable Diffusion - Technical Art
        let sdPrompt = Prompt(
            title: "default_prompt_sd_title".localized(for: language),
            content: "default_prompt_sd_content".localized(for: language),
            folder: PredefinedCategory.stableDiffusion.displayName,
            icon: PredefinedCategory.stableDiffusion.icon
        )
        _ = PromptEntity.create(from: sdPrompt, in: context)
        
        // 6. Vibe Coding - Fast UI
        let vibePrompt = Prompt(
            title: "default_prompt_vibe_coding_title".localized(for: language),
            content: "default_prompt_vibe_coding_content".localized(for: language),
            folder: PredefinedCategory.vibeCoding.displayName,
            icon: PredefinedCategory.vibeCoding.icon
        )
        _ = PromptEntity.create(from: vibePrompt, in: context)
        
        // 7. Windsurf - Rules
        let windsurfPrompt = Prompt(
            title: "default_prompt_windsurf_title".localized(for: language),
            content: "default_prompt_windsurf_content".localized(for: language),
            folder: PredefinedCategory.windsurf.displayName,
            icon: PredefinedCategory.windsurf.icon
        )
        _ = PromptEntity.create(from: windsurfPrompt, in: context)

        dataController.save()
        UserDefaults.standard.set(true, forKey: seedKey)
        self.loadPrompts() // Recargar para que aparezcan inmediatamente
        print("✅ Prompts de ejemplo actualizados.")
    }
    
    // MARK: - Operaciones CRUD

    private func fetchPromptSummaries(trashDict: [String: Date]) -> Result<[Prompt], Error> {
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

                let entities = try context.fetch(request)
                prompts = entities.map { entity in
                    var prompt = entity.toPrompt()
                    // Aplicar la fecha de eliminación desde el diccionario de la papelera
                    if let trashDate = trashDict[entity.id.uuidString] {
                        prompt.deletedAt = trashDate
                    }
                    return prompt
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
    
    /// Carga todos los prompts desde Core Data (excluye los de la papelera)
    func loadPrompts() {
        DispatchQueue.main.async { self.isLoading = true }

        // IMPORTANTE: Para performance, NO cargamos blobs de imágenes en la lista.
        // Usamos `dictionaryResultType` + `showcaseImageCount` para evitar beachball al abrir preview.
        let trashDict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fetchResult = self.fetchPromptSummaries(trashDict: trashDict)
            DispatchQueue.main.async {
                switch fetchResult {
                case .failure(let error):
                    print("Error cargando prompts: \(error)")
                    self.isLoading = false
                    return
                case .success(let allPrompts):
                    self.prompts = allPrompts.filter { !$0.isInTrash }
                    self.trashedPrompts = allPrompts.filter { $0.isInTrash }.sorted {
                        ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
                    }
                    self.filterPrompts(query: self.searchQuery)
                    ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
                    self.isLoading = false
                }
            }
        }
    }

    /// Obtiene un prompt desde Core Data (opcionalmente incluyendo imágenes).
    func fetchPrompt(byId id: UUID, includeImages: Bool) async -> Prompt? {
        await withCheckedContinuation { continuation in
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
                        var p = Prompt(title: entity.title, content: entity.content, folder: entity.folder)
                        p.id = entity.id
                        p.isFavorite = entity.isFavorite
                        p.createdAt = entity.createdAt
                        p.modifiedAt = entity.modifiedAt
                        p.useCount = Int(entity.useCount)
                        p.lastUsedAt = entity.lastUsedAt
                        p.icon = entity.icon
                        p.promptDescription = entity.promptDescription
                        p.deletedAt = entity.deletedAt
                        p.negativePrompt = entity.negativePrompt
                        p.alternativePrompt = entity.alternativePrompt
                        p.customShortcut = entity.customShortcut
                        p.showcaseImagePaths = [entity.image1Path, entity.image2Path, entity.image3Path].compactMap { $0 }
                        p.showcaseThumbnails = [entity.thumb1, entity.thumb2, entity.thumb3].compactMap { $0 }

                        if includeImages {
                            if !p.showcaseImagePaths.isEmpty {
                                p.showcaseImages = p.showcaseImagePaths.compactMap { ImageStore.shared.loadData(relativePath: $0) }
                                p.showcaseImageCount = p.showcaseImages.count
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

    /// Carga únicamente las imágenes de resultados para un prompt.
    func fetchShowcaseImages(byId id: UUID) async -> [Data] {
        let full = await fetchPrompt(byId: id, includeImages: true)
        return full?.showcaseImages ?? []
    }

    /// Carga únicamente los paths relativos de las imágenes de resultados para un prompt.
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
    
    /// Carga todas las carpetas desde Core Data aplicando el orden guardado
    func loadFolders() {
        let request = FolderEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            var loadedFolders = entities.map { $0.toFolder() }
            
            switch folderSortMode {
            case .name:
                loadedFolders.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            case .newest:
                loadedFolders.sort { $0.createdAt > $1.createdAt }
            }
            
            DispatchQueue.main.async {
                self.folders = loadedFolders
            }
        } catch {
            print("Error cargando carpetas: \(error)")
        }
    }
    
    /// Persiste un nuevo orden de carpetas
    func reorderFolders(_ folders: [Folder]) {
        let order = folders.map { $0.id.uuidString }
        UserDefaults.standard.set(order, forKey: "folderSortOrder")
        
        DispatchQueue.main.async {
            self.folders = folders
        }
    }
    
    /// Crea un nuevo prompt
    func createPrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let entity = PromptEntity(context: context)
        entity.id = prompt.id
        entity.createdAt = prompt.createdAt
        entity.updateFromPrompt(prompt) // metadata

        // Guardar imágenes en disco + thumbnails en Core Data
        applyShowcaseImages(prompt.showcaseImages, to: entity, promptId: prompt.id, clearExisting: true)

        dataController.save()
        loadPrompts()
        return true
    }
    
    /// Actualiza un prompt existente
    func updatePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.updateFromPrompt(prompt)

                // Solo reescribir imágenes si el caller nos pasa imágenes explícitas (o quiere borrar todas).
                if !prompt.showcaseImages.isEmpty || prompt.showcaseImageCount == 0 {
                    applyShowcaseImages(prompt.showcaseImages, to: entity, promptId: prompt.id, clearExisting: true)
                }
                dataController.save()
                loadPrompts()
                return true
            }
        } catch {
            print("Error actualizando prompt: \(error)")
        }
        
        return false
    }

    /// Actualiza solo las imágenes de showcase (y su conteo) en background.
    func updateShowcaseImages(promptId: UUID, images: [Data]) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                let context: NSManagedObjectContext = self.dataController.backgroundContext
                var ok = false

                context.performAndWaitCompat {
                    let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", promptId as CVarArg)
                    request.fetchLimit = 1

                    do {
                        guard let entity = try context.fetch(request).first else { return }
                        self.applyShowcaseImages(images, to: entity, promptId: promptId, clearExisting: true)
                        entity.modifiedAt = Date()

                        try context.save()
                        ok = true
                    } catch {
                        print("Error actualizando imágenes de showcase: \(error)")
                    }
                }

                if ok {
                    DispatchQueue.main.async { self.loadPrompts() }
                }
                continuation.resume(returning: ok)
            }
        }
    }

    private func applyShowcaseImages(_ images: [Data], to entity: PromptEntity, promptId: UUID, clearExisting: Bool) {
        let existingPaths = [entity.image1Path, entity.image2Path, entity.image3Path].compactMap { $0 }
        if clearExisting, !existingPaths.isEmpty {
            ImageStore.shared.delete(relativePaths: existingPaths)
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
    
    // MARK: - Papelera (Soft Delete)
    
    /// Mueve prompt a la papelera (soft delete)
    func deletePrompt(_ prompt: Prompt) -> Bool {
        var trashed = prompt
        trashed.deletedAt = Date()
        return updatePrompt(trashed)
    }

    /// Mueve múltiples prompts a la papelera en una sola operación (evita recargar por cada item)
    func deletePrompts(withIds ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        let context = dataController.viewContext
        let nsuuids = ids.map { $0 as NSUUID }

        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", nsuuids)

        do {
            let entities = try context.fetch(request)
            let now = Date()
            for entity in entities {
                entity.deletedAt = now
                entity.modifiedAt = now
            }
            dataController.save()
            loadPrompts()
            return true
        } catch {
            print("Error eliminando prompts en lote: \(error)")
            return false
        }
    }

    /// Mueve múltiples prompts a una carpeta/categoría en una sola operación
    func movePrompts(withIds ids: [UUID], toFolder folderName: String?) -> Bool {
        guard !ids.isEmpty else { return false }
        let context = dataController.viewContext
        let nsuuids = ids.map { $0 as NSUUID }

        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", nsuuids)

        do {
            let entities = try context.fetch(request)
            let now = Date()
            for entity in entities {
                entity.folder = folderName
                entity.modifiedAt = now
            }
            dataController.save()
            loadPrompts()
            return true
        } catch {
            print("Error moviendo prompts en lote: \(error)")
            return false
        }
    }

    /// Marca múltiples prompts como favoritos en una sola operación
    func markPromptsFavorite(withIds ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        let context = dataController.viewContext
        let nsuuids = ids.map { $0 as NSUUID }

        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", nsuuids)

        do {
            let entities = try context.fetch(request)
            let now = Date()
            for entity in entities {
                entity.isFavorite = true
                entity.modifiedAt = now
            }
            dataController.save()
            loadPrompts()
            return true
        } catch {
            print("Error marcando favoritos en lote: \(error)")
            return false
        }
    }
    
    /// Restaura un prompt desde la papelera
    func restorePrompt(_ prompt: Prompt) -> Bool {
        var restored = prompt
        restored.deletedAt = nil
        return updatePrompt(restored)
    }
    
    /// Elimina un prompt permanentemente de CoreData
    func permanentlyDeletePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                // Limpiar también el UserDefaults del trash
                var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
                dict.removeValue(forKey: prompt.id.uuidString)
                UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)

                // Limpiar imágenes en disco
                ImageStore.shared.deleteAllImages(for: prompt.id)
                
                context.delete(entity)
                dataController.save()
                loadPrompts()
                return true
            }
        } catch {
            print("Error eliminando prompt permanentemente: \(error)")
        }
        return false
    }
    
    /// Elimina todos los prompts de la papelera de forma permanente
    func emptyTrash() {
        for prompt in trashedPrompts {
            _ = permanentlyDeletePrompt(prompt)
        }
    }
    
    /// Elimina automáticamente los prompts con más de 7 días de eliminación
    private func purgeExpiredTrash() {
        let context = dataController.viewContext
        let request = PromptEntity.fetchAll(in: context)
        
        guard let entities = try? context.fetch(request) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        
        var purgedCount = 0
        for entity in entities {
            if let deletedAt = entity.deletedAt, deletedAt < cutoff {
                // Limpiar UserDefaults
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
    
    // MARK: - Operaciones de Carpetas
    
    /// Crea una nueva carpeta
    func createFolder(_ folder: Folder) -> Bool {
        let context = dataController.viewContext
        _ = FolderEntity.create(from: folder, in: context)
        dataController.save()
        loadFolders()
        return true
    }
    
    /// Actualiza una carpeta existente
    func updateFolder(_ folder: Folder, oldName: String? = nil) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.updateFromFolder(folder)
                
                // Si el nombre cambió, actualizar todos los prompts asociados
                if let oldName = oldName, oldName != folder.name {
                    let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    promptRequest.predicate = NSPredicate(format: "folder == %@", oldName)
                    
                    let promptEntities = try context.fetch(promptRequest)
                    for promptEntity in promptEntities {
                        promptEntity.folder = folder.name
                    }
                }
                
                dataController.save()
                loadFolders()
                loadPrompts()
                return true
            }
        } catch {
            print("Error actualizando carpeta: \(error)")
        }
        
        return false
    }
    
    /// Elimina una carpeta
    func deleteFolder(_ folder: Folder) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                // Desasociar prompts antes de borrar la carpeta
                let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                promptRequest.predicate = NSPredicate(format: "folder == %@", folder.name)
                
                let promptEntities = try context.fetch(promptRequest)
                for promptEntity in promptEntities {
                    promptEntity.folder = nil
                }
                
                context.delete(entity)
                dataController.save()
                loadFolders()
                loadPrompts()
                return true
            }
        } catch {
            print("Error eliminando carpeta: \(error)")
        }
        
        return false
    }
    
    // MARK: - Búsqueda y Filtrado
    
    /// Filtra prompts basado en consulta de búsqueda y categoría seleccionada
    private func filterPrompts(query: String, categoryOverride: String? = "USE_CURRENT") {
        var filtered = prompts
        
        // Determinar qué categoría usar (la del override o la actual)
        let category: String?
        if let override = categoryOverride, override == "USE_CURRENT" {
            category = selectedCategory
        } else {
            category = categoryOverride
        }
        
        // Filtrar por categoría si hay una seleccionada
        if let category = category {
            switch category {
            case "recent":
                let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 3600)
                let recentlyUsed = prompts.filter { 
                    if let lastUsed = $0.lastUsedAt { return lastUsed > fortyEightHoursAgo }
                    return false 
                }
                
                let mostUsed = prompts.filter { $0.useCount > 0 }
                    .sorted { $0.useCount > $1.useCount }
                    .prefix(10)
                
                var combined = recentlyUsed
                for p in mostUsed {
                    if !combined.contains(where: { $0.id == p.id }) {
                        combined.append(p)
                    }
                }
                
                combined.sort { ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast) }
                filtered = Array(combined.prefix(7))
                
            case "favorites":
                filtered = filtered.filter { $0.isFavorite }
                filtered.sort { $0.useCount > $1.useCount }
                
            case "uncategorized":
                filtered = filtered.filter { $0.folder == nil || $0.folder == "" }
            default:
                filtered = filtered.filter { $0.folder == category }
            }
        }
        
        // --- Smart Boost based on Active Application ---
        if let activeApp = activeAppBundleID, !activeApp.isEmpty {
            if query.isEmpty {
                let matched = filtered.filter { $0.targetAppBundleIDs.contains(activeApp) }
                let others = filtered.filter { !$0.targetAppBundleIDs.contains(activeApp) }
                filtered = matched + others
            }
        }
        
        // Filtrar por texto si hay consulta - MOTOR DE BÚSQUEDA AVANZADO (Fuzzy + Phrasal + Weighted)
        if !query.isEmpty {
            // 0. SANITIZACIÓN Y NORMALIZACIÓN
            // Limpiar caracteres de control y normalizar espacios múltiples (fuera de frases exactas)
            let sanitized = query.replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression)
            let normalizedSpaces = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let originalQuery = normalizedSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !originalQuery.isEmpty else { 
                filteredPrompts = filtered
                return 
            }
            
            // 1. EXTRAER FRASES EXACTAS (entre comillas)
            var phrasalQueries: [String] = []
            var remainingQuery = originalQuery
            
            let regex = try? NSRegularExpression(pattern: "\"([^\"]+)\"", options: [])
            if let matches = regex?.matches(in: originalQuery, options: [], range: NSRange(originalQuery.startIndex..., in: originalQuery)) {
                for match in matches.reversed() { // Reversa para no corromper índices al remover
                    if let range = Range(match.range(at: 1), in: originalQuery) {
                        phrasalQueries.append(originalQuery[range].lowercased())
                    }
                    if let fullRange = Range(match.range(at: 0), in: originalQuery) {
                        remainingQuery.removeSubrange(fullRange)
                    }
                }
            }
            
            // 2. NORMALIZACIÓN Y KEYWORDS RESTANTES
            let normalizedRemaining = remainingQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let keywords = normalizedRemaining.components(separatedBy: .whitespaces)
                .filter { $0.count >= 2 } // Ignorar conectores de 1 letra
            
            // 3. SCORING AVANZADO
            let scoredPrompts = filtered.map { prompt -> (Prompt, Int) in
                var score = 0
                let title = prompt.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let content = prompt.content.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let folder = (prompt.folder ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                
                // --- A. VALIDACIÓN DE FRASES COINCIDENTES ("Exact Match") ---
                for phrase in phrasalQueries {
                    if title.contains(phrase) { score += 500 }
                    else if content.contains(phrase) { score += 200 }
                    else { return (prompt, 0) } // Si pidió frase exacta y no está, descartar
                }
                
                // --- B. VALIDACIÓN DE KEYWORDS (Lógica AND Flexible + FUZZY) ---
                for kw in keywords {
                    var kwFound = false
                    
                    // B1. COINCIDENCIA POR PREFIJO (Muy relevante: Escribes "mar" y sale "Marketing")
                    if title.hasPrefix(kw) { score += 150; kwFound = true }
                    else if title.contains(" " + kw) { score += 100; kwFound = true } // Inicio de cualquier palabra en título
                    
                    // B2. FUZZY MATCHING (Tolerancia a 1 error en palabras > 4 letras)
                    if !kwFound && kw.count > 4 {
                        // Comprobamos si hay una coincidencia aproximada (simple fuzzy)
                        // Si la palabra está casi bien escrita en el título
                        let titleWords = title.components(separatedBy: .whitespaces)
                        for word in titleWords where word.count > 3 {
                            if word.commonPrefix(with: kw).count >= kw.count - 1 {
                                score += 60 // Casi coincide
                                kwFound = true
                                break
                            }
                        }
                    }
                    
                    // B3. BÚSQUEDA EN CONTENIDO
                    if !kwFound && content.contains(kw) { 
                        score += 30
                        kwFound = true
                    }
                    
                    // B4. BÚSQUEDA EN CATEGORÍA
                    if !kwFound && folder.contains(kw) {
                        score += 20
                        kwFound = true
                    }
                    
                    // Si el usuario escribió una palabra y no está NI PARECIDA, penalizamos o descartamos
                    if !kwFound { score -= 20 }
                }
                
                // --- C. BONUS POR RECIENCIA Y USO ---
                if score > 0 {
                    score += Int(prompt.useCount) / 2
                    if prompt.isFavorite { score += 40 }
                    
                    // Bonus por reciencia: Si se tocó en la última semana, impulsamos un poco
                    let lastWeek = Date().addingTimeInterval(-7 * 86400)
                    if prompt.modifiedAt > lastWeek {
                        score += 30
                    }
                    if prompt.modifiedAt > Date().addingTimeInterval(-24 * 3600) {
                        score += 20 // Acumulativo si es muy muy reciente
                    }
                    
                    // BONUS POR APP ACTIVA
                    if let activeApp = activeAppBundleID, prompt.targetAppBundleIDs.contains(activeApp) {
                        score += 500 // Impulso masivo para matches de app
                    }
                }
                
                return (prompt, score)
            }
            
            filtered = scoredPrompts
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
        }
        
        // CONFIGURABLE: Límite de resultados mostrados comentado para que se muestren todos en la categoría
        // if filtered.count > 50 {
        //    filtered = Array(filtered.prefix(50))
        // }
        
        // --- Terminal Global Sort ---
        if query.isEmpty {
            switch promptSortMode {
            case .name:
                filtered.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
            case .newest:
                // Priorizar los más recientemente modificados para que reflejen la actividad real
                filtered.sort { $0.modifiedAt > $1.modifiedAt }
            case .mostUsed:
                filtered.sort { $0.useCount > $1.useCount }
            }
        }
        
        filteredPrompts = filtered
    }
    
    /// Obtiene prompts favoritos
    func getFavoritePrompts() -> [Prompt] {
        return prompts.filter { $0.isFavorite }
            .sorted { $0.useCount > $1.useCount }
    }
    
    /// Busca prompts por carpeta
    func getPromptsInFolder(_ folder: String) -> [Prompt] {
        return prompts.filter { $0.folder == folder }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    /// Obtiene todos los prompts
    func getAllPrompts() -> [Prompt] {
        return prompts
    }
    
    /// Exporta todos los prompts a texto plano
    func exportAllPrompts() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        
        var exportText = "=== PROMPTS EXPORTADOS ===\n"
        exportText += "Fecha: \(timestamp)\n\n"
        
        for prompt in prompts {
            exportText += "Título: \(prompt.title)\n"
            exportText += "Contenido:\n\(prompt.content)\n"
            exportText += "---\n\n"
        }
        
        return exportText
    }
    
    /// Exporta toda la base de datos (Prompts + Carpetas) en formato JSON
    func exportAllPromptsAsJSON() -> Data? {
        do {
            // Export debe incluir imágenes aunque la lista use lazy-load.
            // NOTA: JSON es portable (incluye imágenes en base64), pero puede ser pesado.
            let context: NSManagedObjectContext = dataController.backgroundContext
            var allPrompts: [Prompt] = []
            var allFolders: [Folder] = []

            context.performAndWaitCompat {
                do {
                    let folderRequest = FolderEntity.fetchAll(in: context)
                    allFolders = try context.fetch(folderRequest).map { $0.toFolder() }

                    let request = PromptEntity.fetchAll(in: context)
                    let entities = try context.fetch(request)
                    allPrompts = entities.map { entity in
                        var p = entity.toPrompt()
                        // Incluir imágenes completas (para que el JSON sea auto-contenido).
                        if !p.showcaseImagePaths.isEmpty {
                            p.showcaseImages = p.showcaseImagePaths.compactMap { ImageStore.shared.loadData(relativePath: $0) }
                            p.showcaseImageCount = p.showcaseImages.count
                        } else {
                            let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                            p.showcaseImages = legacy
                            p.showcaseImageCount = legacy.count
                        }
                        return p
                    }
                } catch {
                    print("❌ Error preparando export JSON: \(error)")
                }
            }

            let package = BackupPackage(
                version: "2.3",
                prompts: allPrompts,
                folders: allFolders
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(package)
        } catch {
            print("❌ Error codificando backup a JSON: \(error)")
            return nil
        }
    }

    /// Exporta un backup completo en ZIP (manifest JSON + carpeta Images con archivos).
    /// - Importante: a diferencia del JSON, el manifest NO incluye imágenes en base64.
    func exportBackupZip(to destinationZipURL: URL) -> Bool {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("promtier_backup_\(UUID().uuidString)", isDirectory: true)
        let bundleRoot = tempRoot.appendingPathComponent("Promtier Backup", isDirectory: true)
        let imagesRoot = bundleRoot.appendingPathComponent("Images", isDirectory: true)
        let manifestURL = bundleRoot.appendingPathComponent("manifest.json", isDirectory: false)

        do {
            try fm.createDirectory(at: imagesRoot, withIntermediateDirectories: true)

            let context: NSManagedObjectContext = dataController.backgroundContext
            var allPrompts: [Prompt] = []
            var allFolders: [Folder] = []

            context.performAndWaitCompat {
                do {
                    let folderRequest = FolderEntity.fetchAll(in: context)
                    allFolders = try context.fetch(folderRequest).map { $0.toFolder() }

                    let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "useCount", ascending: false),
                        NSSortDescriptor(key: "modifiedAt", ascending: false)
                    ]
                    let entities = try context.fetch(request)

                    // Asegurar que prompts legacy tengan paths en disco antes de exportar.
                    var didChange = false
                    for entity in entities {
                        let hasPaths = (entity.image1Path != nil || entity.image2Path != nil || entity.image3Path != nil)
                        if !hasPaths {
                            let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                            if !legacy.isEmpty {
                                self.applyShowcaseImages(legacy, to: entity, promptId: entity.id, clearExisting: true)
                                didChange = true
                            }
                        }
                    }
                    if didChange, context.hasChanges {
                        try context.save()
                    }

                    allPrompts = entities.map { entity in
                        var p = entity.toPrompt()
                        // Mantener manifest ligero: las imágenes viajan como archivos en /Images (y thumbs se regeneran al importar).
                        p.showcaseThumbnails = []
                        p.showcaseImages = []
                        return p
                    }
                } catch {
                    print("❌ Error preparando backup ZIP: \(error)")
                }
            }

            let archive = BackupArchive(
                version: "3.0",
                exportedAt: Date(),
                prompts: allPrompts,
                folders: allFolders
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let manifestData = try encoder.encode(archive)
            try manifestData.write(to: manifestURL, options: [.atomic])

            // Copiar imágenes referenciadas al bundle (sin cargar en memoria completa).
            var copied = Set<String>()
            for prompt in allPrompts {
                for rel in Array(prompt.showcaseImagePaths.prefix(3)) {
                    guard let safeRel = sanitizeRelativeImagePath(rel) else { continue }
                    guard copied.insert(safeRel).inserted else { continue }

                    let sourceURL = ImageStore.shared.url(forRelativePath: safeRel)
                    guard fm.fileExists(atPath: sourceURL.path) else { continue }

                    let destURL = imagesRoot.appendingPathComponent(safeRel, isDirectory: false)
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: destURL.path) { try? fm.removeItem(at: destURL) }
                    try fm.copyItem(at: sourceURL, to: destURL)
                }
            }

            if fm.fileExists(atPath: destinationZipURL.path) { try? fm.removeItem(at: destinationZipURL) }
            try ZipService.zip(directory: bundleRoot, to: destinationZipURL)
            try? fm.removeItem(at: tempRoot)
            return true
        } catch {
            print("❌ Error exportando backup ZIP: \(error)")
            try? fm.removeItem(at: tempRoot)
            return false
        }
    }

    /// Importa un backup ZIP (manifest + Images). No sobrescribe prompts existentes por ID.
    func importBackupZip(from zipURL: URL) -> (success: Int, failed: Int, foldersCreated: Int) {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("promtier_import_\(UUID().uuidString)", isDirectory: true)

        do {
            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            try ZipService.unzip(zipFile: zipURL, to: tempRoot)

            guard let manifestURL = findFirstFile(named: "manifest.json", under: tempRoot) else {
                print("❌ ZIP inválido: no se encontró manifest.json")
                try? fm.removeItem(at: tempRoot)
                return (0, 0, 0)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(BackupArchive.self, from: Data(contentsOf: manifestURL))

            // El bundle root es el directorio donde vive el manifest.
            let bundleRoot = manifestURL.deletingLastPathComponent()
            let imagesRoot = bundleRoot.appendingPathComponent("Images", isDirectory: true)

            let context: NSManagedObjectContext = dataController.backgroundContext
            let (successCount, failedCount, foldersCreated) = context.performAndWaitCompat { [self] in
                var sCount = 0
                var fCount = 0
                var cCount = 0
                do {
                    // Cache de existentes por ID para evitar fetch por item.
                    let existingPromptIds = try self.fetchExistingPromptIds(in: context)
                    let existingFolderIds = try self.fetchExistingFolderIds(in: context)
                    let existingFolderNames = try self.fetchExistingFolderNames(in: context)

                    var promptIdSet = existingPromptIds
                    var folderIdSet = existingFolderIds
                    var folderNameSet = existingFolderNames

                    // 1) Carpetas
                    for folder in archive.folders {
                        if folderIdSet.contains(folder.id) || folderNameSet.contains(folder.name) { continue }
                        _ = FolderEntity.create(from: folder, in: context)
                        cCount += 1
                        folderIdSet.insert(folder.id)
                        folderNameSet.insert(folder.name)
                    }

                    // 2) Prompts
                    for prompt in archive.prompts {
                        if promptIdSet.contains(prompt.id) {
                            fCount += 1
                            continue
                        }

                        let entity = PromptEntity(context: context)
                        entity.id = prompt.id
                        entity.createdAt = prompt.createdAt
                        entity.updateFromPrompt(prompt)

                        let paths = Array(prompt.showcaseImagePaths.prefix(3)).compactMap(self.sanitizeRelativeImagePath(_:))
                        var thumbs: [Data] = []

                        if !paths.isEmpty {
                            for rel in paths {
                                let sourceURL = imagesRoot.appendingPathComponent(rel, isDirectory: false)
                                guard fm.fileExists(atPath: sourceURL.path) else { continue }

                                let destURL = ImageStore.shared.url(forRelativePath: rel)
                                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                                if fm.fileExists(atPath: destURL.path) { try? fm.removeItem(at: destURL) }
                                try fm.copyItem(at: sourceURL, to: destURL)

                                if let data = try? Data(contentsOf: destURL),
                                   let thumb = ImageOptimizer.shared.optimizeForDisk(imageData: data, maxPixelSize: 480, compressionQuality: 0.7)?.data {
                                    thumbs.append(thumb)
                                }
                            }
                        }

                        entity.image1Path = paths.indices.contains(0) ? paths[0] : nil
                        entity.image2Path = paths.indices.contains(1) ? paths[1] : nil
                        entity.image3Path = paths.indices.contains(2) ? paths[2] : nil

                        entity.thumb1 = thumbs.indices.contains(0) ? thumbs[0] : nil
                        entity.thumb2 = thumbs.indices.contains(1) ? thumbs[1] : nil
                        entity.thumb3 = thumbs.indices.contains(2) ? thumbs[2] : nil

                        entity.image1 = nil
                        entity.image2 = nil
                        entity.image3 = nil

                        entity.showcaseImageCount = Int16(paths.count)

                        sCount += 1
                        promptIdSet.insert(prompt.id)

                        if sCount % 50 == 0, context.hasChanges {
                            try context.save()
                        }
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    print("❌ Error importando backup ZIP: \(error)")
                }
                
                return (sCount, fCount, cCount)
            }

            DispatchQueue.main.async {
                self.loadFolders()
                self.loadPrompts()
            }

            try? fm.removeItem(at: tempRoot)
            return (successCount, failedCount, foldersCreated)
        } catch {
            print("❌ Error leyendo ZIP: \(error)")
            try? fm.removeItem(at: tempRoot)
            return (0, 0, 0)
        }
    }

    private func sanitizeRelativeImagePath(_ path: String) -> String? {
        if path.isEmpty { return nil }
        if path.hasPrefix("/") { return nil }
        let components = (path as NSString).pathComponents
        if components.contains("..") { return nil }
        return path
    }

    private func findFirstFile(named filename: String, under directory: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == filename { return url }
        }
        return nil
    }

    private func fetchExistingPromptIds(in context: NSManagedObjectContext) throws -> Set<UUID> {
        let request = NSFetchRequest<NSDictionary>(entityName: "PromptEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["id"] as? UUID })
    }

    private func fetchExistingFolderIds(in context: NSManagedObjectContext) throws -> Set<UUID> {
        let request = NSFetchRequest<NSDictionary>(entityName: "FolderEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["id"] as? UUID })
    }

    private func fetchExistingFolderNames(in context: NSManagedObjectContext) throws -> Set<String> {
        let request = NSFetchRequest<NSDictionary>(entityName: "FolderEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["name"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["name"] as? String })
    }
    
    /// Exporta todos los prompts en formato CSV (RFC 4180)
    /// Columnas: id, title, content, folder, icon, isFavorite, useCount, createdAt, modifiedAt
    func exportAllPromptsAsCSV() -> Data? {
        let iso = ISO8601DateFormatter()
        
        // Función helper: envuelve el valor en comillas y escapa las comillas internas
        func csv(_ value: String) -> String {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        
        var rows: [String] = []
        // Cabecera
        rows.append("id,title,content,folder,icon,isFavorite,useCount,createdAt,modifiedAt,lastUsedAt,negativePrompt,alternatives")
        
        for p in prompts {
            let row = [
                csv(p.id.uuidString),
                csv(p.title),
                csv(p.content),
                csv(p.folder ?? ""),
                csv(p.icon ?? ""),
                p.isFavorite ? "true" : "false",
                "\(p.useCount)",
                csv(iso.string(from: p.createdAt)),
                csv(iso.string(from: p.modifiedAt)),
                csv(p.lastUsedAt != nil ? iso.string(from: p.lastUsedAt!) : ""),
                csv(p.negativePrompt ?? ""),
                csv(p.alternatives.joined(separator: " | "))
            ].joined(separator: ",")
            rows.append(row)
        }
        
        let csvString = rows.joined(separator: "\n")
        return csvString.data(using: .utf8)
    }
    
    /// Importa datos desde un archivo JSON (Soporta formato antiguo y nuevo BackupPackage)
    func importPromptsFromData(_ data: Data) -> (success: Int, failed: Int, foldersCreated: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var promptsToImport: [Prompt] = []
        var foldersToImport: [Folder] = []
        var foldersCreated = 0
        
        do {
            // Intentar decodificar como BackupPackage (Nuevo Formato)
            let package = try decoder.decode(BackupPackage.self, from: data)
            promptsToImport = package.prompts
            foldersToImport = package.folders
            print("📦 Detectado formato BackupPackage v\(package.version)")
        } catch {
            // Intentar decodificar como [Prompt] (Formato Antiguo)
            do {
                promptsToImport = try decoder.decode([Prompt].self, from: data)
                print("📄 Detectado formato de lista de prompts (Legacy)")
            } catch {
                print("❌ Error decodificando archivo de importación: \(error)")
                return (0, 0, 0)
            }
        }
        
        // Detectar Carpetas
        for folder in foldersToImport {
            // Evitar duplicados por nombre o ID
            if !folders.contains(where: { $0.id == folder.id || $0.name == folder.name }) {
                if createFolder(folder) {
                    foldersCreated += 1
                }
            }
        }
        
        // 2. Importar Prompts
        var successCount = 0
        var failedCount = 0
        
        for prompt in promptsToImport {
            // Evitar duplicados exactos por ID
            if prompts.contains(where: { $0.id == prompt.id }) {
                failedCount += 1
                continue
            }
            
            if createPrompt(prompt) {
                successCount += 1
            } else {
                failedCount += 1
            }
        }
        
        loadFolders()
        loadPrompts()
        return (successCount, failedCount, foldersCreated)
    }
    
    /// Restablece toda la base de datos (BORRADO TOTAL)
    func resetAllData() {
        let context = dataController.viewContext

        // 0. Wipe de imágenes en disco (para evitar huérfanas)
        ImageStore.shared.wipeAll()
        
        // 1. Eliminar Prompts
        let promptRequest: NSFetchRequest<NSFetchRequestResult> = PromptEntity.fetchRequest()
        let deletePrompts = NSBatchDeleteRequest(fetchRequest: promptRequest)
        
        // 2. Eliminar Carpetas
        let folderRequest: NSFetchRequest<NSFetchRequestResult> = FolderEntity.fetchRequest()
        let deleteFolders = NSBatchDeleteRequest(fetchRequest: folderRequest)
        
        do {
            try context.execute(deletePrompts)
            try context.execute(deleteFolders)
            
            // Limpiar flags de seeding para que se vuelvan a crear al recargar
            UserDefaults.standard.removeObject(forKey: "hasSeededDefaultsV22")
            UserDefaults.standard.removeObject(forKey: "hasSeededInitialPromptsV23")
            UserDefaults.standard.removeObject(forKey: "hasMigratedShowcaseImagesToDiskV1")
            UserDefaults.standard.removeObject(forKey: "hasMigratedShowcaseImageCountV1")
            
            dataController.save()
            
            // Volver a sembrar datos limpios
            seedDefaultFolders()
            seedDefaultPrompts()
            
            loadFolders()
            loadPrompts()
            
            print("⚠️ Base de datos restablecida completamente")
        } catch {
            print("❌ Error al restablecer base de datos: \(error)")
        }
    }
    
    // MARK: - Operaciones de Uso
    
    /// Registra uso de prompt (contadores y fechas) sin copiar al clipboard
    func recordPromptUse(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.recordUse()
        _ = updatePrompt(updatedPrompt)
    }
    
    /// Registra uso de prompt y lo copia al clipboard (Versión estándar)
    func usePrompt(_ prompt: Prompt, contentOverride: String? = nil) {
        let contentToCopy = contentOverride ?? prompt.content
        recordPromptUse(prompt)
        clipboardService.copyToClipboard(contentToCopy)
    }
    
    /// Copia prompt con variables de plantilla (Legacy/Internal)
    func usePromptWithVariables(_ prompt: Prompt, variables: [String: String]) {
        var processedContent = prompt.content
        for (key, value) in variables {
            processedContent = processedContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        clipboardService.copyToClipboard(processedContent)
        recordPromptUse(prompt)
    }
    
    // MARK: - Estadísticas
    
    /// Obtiene prompts más usados
    func getMostUsedPrompts(limit: Int = 10) -> [Prompt] {
        return prompts.sorted { $0.useCount > $1.useCount }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Obtiene prompts recientemente modificados
    func getRecentlyModifiedPrompts(limit: Int = 10) -> [Prompt] {
        return prompts.sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Obtiene estadísticas generales
    func getStatistics() -> (total: Int, favorites: Int, totalUses: Int) {
        let total = prompts.count
        let favorites = prompts.filter { $0.isFavorite }.count
        let totalUses = prompts.reduce(0) { $0 + $1.useCount }
        
        return (total, favorites, totalUses)
    }
}

// MARK: - Estructuras de Soporte para Transferencia

/// Paquete completo de copia de seguridad
struct BackupPackage: Codable {
    var version: String
    var prompts: [Prompt]
    var folders: [Folder]
}
