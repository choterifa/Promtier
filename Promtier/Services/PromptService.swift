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
import SwiftUI

// SERVICIO PRINCIPAL: Gestión completa de prompts
class PromptService: ObservableObject {
    static let shared = PromptService()
    let searchEngine = PromptSearchEngine()

    enum ShowcaseImageLoadPolicy {
        static let runtimeMaxImages = 3
        static let runtimeMaxTotalBytes = 24 * 1024 * 1024
    }
    
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
    
    @Published var folderSortMode: FolderSortMode = .newest {
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
    private var filterTask: Task<Void, Never>?
    private var promptLookup: [UUID: Prompt] = [:]
    private var searchIndex: [UUID: PromptSearchDocument] = [:]

    private struct PromptSearchDocument: Sendable {
        let normalizedTitle: String
        let normalizedContent: String
        let normalizedFolder: String
        let titleWords: [String]
    }
    
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
        removeDuplicatePrompts() // Limpiar posibles duplicados por el bug de sembrado
        seedDefaultPrompts() // Crear prompts de ejemplo iniciales
        purgeExpiredTrash()  // Limpiar papelera de entradas > 7 días
        loadFolders()
        loadPrompts()
        migrateShowcaseImageCountIfNeeded()
        migrateShowcaseBlobsToDiskIfNeeded()
        repairMissingShowcaseReferencesIfNeeded()
    }
    
    /// Elimina duplicados que hayan sido generados accidentalmente por semillas anteriores
    private func removeDuplicatePrompts() {
        PromptRepository.shared.removeDuplicatePrompts()
    }

    private func migrateShowcaseImageCountIfNeeded() {
        PromptRepository.shared.onDataChanged = { [weak self] in DispatchQueue.main.async { self?.loadPrompts() } }
        PromptRepository.shared.migrateShowcaseImageCountIfNeeded()
    }

    private func migrateShowcaseBlobsToDiskIfNeeded() {
        PromptRepository.shared.migrateShowcaseBlobsToDiskIfNeeded()
    }
    
    /// Crea las carpetas por defecto si no han sido sembradas aún en esta versión
    private func seedDefaultFolders() {
        let context = dataController.viewContext
        
        // Usamos un flag de versión para asegurar que se siembren al menos una vez al actualizar
        let seedKey = "hasSeededDefaultsV28" // BUMP VERSION
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
        let seedKey = "hasSeededInitialPromptsV28" // BUMP VERSION
        if UserDefaults.standard.bool(forKey: seedKey) { return }
        
        print("🌱 Sembrando prompts de ejemplo realistas (V28)...")
        
        let language = PreferencesManager.shared.language
        
        // Helper function to check if prompt exists
        func promptExists(id: UUID) -> Bool {
            let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return (try? context.count(for: request)) ?? 0 > 0
        }
        
        // 1. ChatGPT - Marketing (Suggested App)
        let chatGPTPromptId = UUID(uuidString: "88888888-8888-4444-AAAA-000000000001")!
        if !promptExists(id: chatGPTPromptId) {
            var chatGPTPrompt = Prompt(
                title: "default_prompt_chatgpt_title".localized(for: language),
                content: "default_prompt_chatgpt_content".localized(for: language),
                folder: PredefinedCategory.chatGPT.displayName,
                icon: PredefinedCategory.chatGPT.icon
            )
            chatGPTPrompt.id = chatGPTPromptId
            chatGPTPrompt.targetAppBundleIDs = ["com.apple.Safari"]
            _ = PromptEntity.create(from: chatGPTPrompt, in: context)
        }
        
        // 2. Claude - SOLID (Shortcut)
        let claudePromptId = UUID(uuidString: "88888888-8888-4444-AAAA-000000000002")!
        if !promptExists(id: claudePromptId) {
            var claudePrompt = Prompt(
                title: "default_prompt_claude_title".localized(for: language),
                content: "default_prompt_claude_content".localized(for: language),
                folder: PredefinedCategory.claude.displayName,
                icon: PredefinedCategory.claude.icon
            )
            claudePrompt.id = claudePromptId
            claudePrompt.customShortcut = "review"
            _ = PromptEntity.create(from: claudePrompt, in: context)
        }
        
        // 3. Cursor - Implementation (Negative Prompt)
        let cursorPromptId = UUID(uuidString: "88888888-8888-4444-AAAA-000000000003")!
        if !promptExists(id: cursorPromptId) {
            var cursorPrompt = Prompt(
                title: "default_prompt_cursor_title".localized(for: language),
                content: "default_prompt_cursor_content".localized(for: language),
                folder: PredefinedCategory.cursor.displayName,
                icon: PredefinedCategory.cursor.icon
            )
            cursorPrompt.id = cursorPromptId
            cursorPrompt.negativePrompt = "default_negative_cursor".localized(for: language)
            _ = PromptEntity.create(from: cursorPrompt, in: context)
        }
        
        // 4. Midjourney - Portrait (Versions)
        let midjourneyPromptId = UUID(uuidString: "88888888-8888-4444-AAAA-000000000004")!
        if !promptExists(id: midjourneyPromptId) {
            var midjourneyPrompt = Prompt(
                title: "default_prompt_midjourney_title".localized(for: language),
                content: "default_prompt_midjourney_content".localized(for: language),
                folder: PredefinedCategory.midjourney.displayName,
                icon: PredefinedCategory.midjourney.icon
            )
            midjourneyPrompt.id = midjourneyPromptId
            midjourneyPrompt.versionHistory = [
                PromptSnapshot(id: UUID(), title: midjourneyPrompt.title, content: "Initial cinematic prompt", timestamp: Date().addingTimeInterval(-86400)),
                PromptSnapshot(id: UUID(), title: midjourneyPrompt.title, content: "Added --v 6.0 and lighting details", timestamp: Date().addingTimeInterval(-3600))
            ]
            _ = PromptEntity.create(from: midjourneyPrompt, in: context)
        }
        
        // 5. Images Prompts - Otaku Room (Full Detail + Negative)
        let imagesPromptId = UUID(uuidString: "88888888-8888-4444-AAAA-000000000005")!
        if !promptExists(id: imagesPromptId) {
            var imagesPrompt = Prompt(
                title: "default_prompt_images_title".localized(for: language),
                content: "default_prompt_images_content".localized(for: language),
                folder: PredefinedCategory.imagesPrompts.displayName,
                icon: PredefinedCategory.imagesPrompts.icon
            )
            imagesPrompt.id = imagesPromptId
            imagesPrompt.negativePrompt = "default_negative_otaku".localized(for: language)
            _ = PromptEntity.create(from: imagesPrompt, in: context)
        }
        
        dataController.save()
        UserDefaults.standard.set(true, forKey: seedKey)
        self.loadPrompts() // Recargar para que aparezcan inmediatamente
        print("✅ Prompts de ejemplo verificados y creados si no existían.")
    }
    
    // MARK: - Search Index Helpers

    func loadShowcaseImages(
        from paths: [String],
        maxImages: Int = ShowcaseImageLoadPolicy.runtimeMaxImages,
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

    private func rebuildPromptLookup(with prompts: [Prompt]) {
        var lookup: [UUID: Prompt] = [:]
        lookup.reserveCapacity(prompts.count)
        for prompt in prompts { lookup[prompt.id] = prompt }
        self.promptLookup = lookup
    }
    
    private func upsertPromptLookup(with prompt: Prompt) {
        promptLookup[prompt.id] = prompt
    }
    
    private func removePromptLookup(for id: UUID) {
        promptLookup.removeValue(forKey: id)
    }

    func promptSnapshot(byId id: UUID) -> Prompt? {
        promptLookup[id]
    }
    
    // MARK: - Operaciones CRUD

    private func fetchPromptSummaries(trashDict: [String: Date]) -> Result<[Prompt], Error> {
        return PromptRepository.shared.fetchPromptSummaries(trashDict: trashDict)
    }

    private func repairMissingShowcaseReferencesIfNeeded() {
        PromptRepository.shared.repairMissingShowcaseReferencesIfNeeded()
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
                    self.rebuildPromptLookup(with: self.prompts); self.searchEngine.rebuildPromptIndices(with: self.prompts)
                    self.filterPrompts(query: self.searchQuery)
                    ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
                    self.isLoading = false
                }
            }
        }
    }

    /// Obtiene un prompt desde Core Data (opcionalmente incluyendo imágenes).
    func fetchPrompt(byId id: UUID, includeImages: Bool) async -> Prompt? {
        return await PromptRepository.shared.fetchPrompt(byId: id, includeImages: includeImages)
    }

    /// Carga únicamente las imágenes de resultados para un prompt.
    func fetchShowcaseImages(byId id: UUID) async -> [Data] {
        return await PromptRepository.shared.fetchShowcaseImages(byId: id)
    }

    /// Carga únicamente los paths relativos de las imágenes de resultados para un prompt.
    func fetchShowcaseImagePaths(byId id: UUID) async -> [String] {
        return await PromptRepository.shared.fetchShowcaseImagePaths(byId: id)
    }
    
        /// Carga todas las carpetas desde Core Data aplicando el orden guardado
        func loadFolders() {
            let request = FolderEntity.fetchAll(in: dataController.viewContext)
    
            do {
                let entities = try dataController.viewContext.fetch(request)
                var loadedFolders = entities.map { $0.toFolder() }
    
                if let savedOrder = UserDefaults.standard.stringArray(forKey: "folderSortOrder"), !savedOrder.isEmpty {
                    var orderedFolders: [Folder] = []
                    
                    // Nuevas carpetas (no están en el orden guardado) van primero (arriba/al lado de uncategorized)
                    let newFolders = loadedFolders.filter { !savedOrder.contains($0.id.uuidString) }
                    orderedFolders.append(contentsOf: newFolders.sorted { $0.createdAt > $1.createdAt })
                    
                    // Luego las que ya tienen un orden guardado
                    for id in savedOrder {
                        if let folder = loadedFolders.first(where: { $0.id.uuidString == id }) {
                            orderedFolders.append(folder)
                        }
                    }
                    
                    loadedFolders = orderedFolders
                } else {
                    switch folderSortMode {
                    case .name:
                        loadedFolders.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
                    case .newest:
                        loadedFolders.sort { $0.createdAt > $1.createdAt }
                    }
                }
    
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.folders = loadedFolders
                    }
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.folders = folders
            }
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
                let updatedPrompt = entity.toPrompt()
                applyUpdatedPromptToInMemoryState(updatedPrompt)
                return true
            }
        } catch {
            print("Error actualizando prompt: \(error)")
        }
        
        return false
    }

    /// Actualiza el estado publicado sin forzar una recarga global de Core Data.
    /// Esto evita bloqueos al usar/cambiar favorito de un prompt.
    private func applyUpdatedPromptToInMemoryState(_ updatedPrompt: Prompt) {
        let apply = {
            var touched = false
            var requiresHotkeyRefresh = false
            let previousPrompt = self.promptLookup[updatedPrompt.id]

            if updatedPrompt.isInTrash {
                if let i = self.prompts.firstIndex(where: { $0.id == updatedPrompt.id }) {
                    self.prompts.remove(at: i)
                    touched = true
                }
                if let i = self.trashedPrompts.firstIndex(where: { $0.id == updatedPrompt.id }) {
                    self.trashedPrompts[i] = updatedPrompt
                    touched = true
                } else {
                    self.trashedPrompts.append(updatedPrompt)
                    touched = true
                }
                self.trashedPrompts.sort { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
                self.removePromptLookup(for: updatedPrompt.id); self.searchEngine.removePromptIndices(for: updatedPrompt.id)
                if previousPrompt?.customShortcut != nil || (previousPrompt == nil && updatedPrompt.customShortcut != nil) {
                    requiresHotkeyRefresh = true
                }
            } else {
                if let i = self.prompts.firstIndex(where: { $0.id == updatedPrompt.id }) {
                    self.prompts[i] = updatedPrompt
                    touched = true
                } else {
                    self.prompts.append(updatedPrompt)
                    touched = true
                }
                if previousPrompt?.customShortcut != updatedPrompt.customShortcut
                    || (previousPrompt == nil && updatedPrompt.customShortcut != nil) {
                    requiresHotkeyRefresh = true
                }
                self.upsertPromptLookup(with: updatedPrompt); self.searchEngine.upsertPromptIndices(with: updatedPrompt)
                if let i = self.trashedPrompts.firstIndex(where: { $0.id == updatedPrompt.id }) {
                    self.trashedPrompts.remove(at: i)
                    touched = true
                }
            }

            // Fallback de seguridad: si no logramos reconciliar en memoria, recargamos completo.
            if !touched {
                self.loadPrompts()
                return
            }

            self.filterPrompts(query: self.searchQuery)
            if requiresHotkeyRefresh {
                ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func applyUpdatedPromptsToInMemoryState(_ updatedPrompts: [Prompt]) {
        guard !updatedPrompts.isEmpty else { return }
        if updatedPrompts.count == 1, let only = updatedPrompts.first {
            applyUpdatedPromptToInMemoryState(only)
            return
        }

        let apply = {
            var touched = false
            var requiresHotkeyRefresh = false
            for prompt in updatedPrompts {
                let previousPrompt = self.promptLookup[prompt.id]
                if prompt.isInTrash {
                    if let i = self.prompts.firstIndex(where: { $0.id == prompt.id }) {
                        self.prompts.remove(at: i)
                        touched = true
                    }
                    if let i = self.trashedPrompts.firstIndex(where: { $0.id == prompt.id }) {
                        self.trashedPrompts[i] = prompt
                        touched = true
                    } else {
                        self.trashedPrompts.append(prompt)
                        touched = true
                    }
                    self.removePromptLookup(for: prompt.id); self.searchEngine.removePromptIndices(for: prompt.id)
                    if previousPrompt?.customShortcut != nil || (previousPrompt == nil && prompt.customShortcut != nil) {
                        requiresHotkeyRefresh = true
                    }
                } else {
                    if let i = self.prompts.firstIndex(where: { $0.id == prompt.id }) {
                        self.prompts[i] = prompt
                        touched = true
                    } else {
                        self.prompts.append(prompt)
                        touched = true
                    }
                    if previousPrompt?.customShortcut != prompt.customShortcut
                        || (previousPrompt == nil && prompt.customShortcut != nil) {
                        requiresHotkeyRefresh = true
                    }
                    self.upsertPromptLookup(with: prompt); self.searchEngine.upsertPromptIndices(with: prompt)
                    if let i = self.trashedPrompts.firstIndex(where: { $0.id == prompt.id }) {
                        self.trashedPrompts.remove(at: i)
                        touched = true
                    }
                }
            }

            if !touched {
                self.loadPrompts()
                return
            }

            self.trashedPrompts.sort { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
            self.filterPrompts(query: self.searchQuery)
            if requiresHotkeyRefresh {
                ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Actualiza solo las imágenes de showcase (y su conteo) en background.
    func updateShowcaseImages(promptId: UUID, images: [Data]) async -> Bool {
        let result = await PromptRepository.shared.updateShowcaseImages(promptId: promptId, images: images)
        if result { DispatchQueue.main.async { self.loadPrompts() } }
        return result
    }

    func applyShowcaseImages(_ images: [Data], to entity: PromptEntity, promptId: UUID, clearExisting: Bool) {
        PromptRepository.shared.applyShowcaseImages(images, to: entity, promptId: promptId, clearExisting: clearExisting)
    }
    
    // MARK: - Papelera (Soft Delete)
    
    /// Mueve prompt a la papelera (soft delete)
    func deletePrompt(_ prompt: Prompt) -> Bool {
        var trashed = prompt
        trashed.deletedAt = Date()
        
        // 1. Update memory eagerly (Optimistic UI update, ultra fast)
        self.applyUpdatedPromptToInMemoryState(trashed)
        
        let targetId = trashed.id
        let targetDate = trashed.deletedAt ?? Date()
        
        // 2. Offload Core Data generic save operation to a background thread / context
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let bgContext = self.dataController.container.newBackgroundContext()
            
            bgContext.performAndWait {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", targetId as CVarArg)
                
                do {
                    if let entity = try bgContext.fetch(request).first {
                        entity.deletedAt = targetDate
                        entity.modifiedAt = targetDate
                        if bgContext.hasChanges { try bgContext.save() }
                    }
                } catch {
                    print("Error soft-deleting in background: \(error)")
                }
            }
        }
        
        return true
    }

    /// Mueve múltiples prompts a la papelera en una sola operación optimizada
    func deletePrompts(withIds ids: [UUID]) -> Bool {
        guard !ids.isEmpty else { return false }
        
        let now = Date()
        var immediateUpdates: [Prompt] = []
        
        // 1. Eagerly update Memory Model
        for id in ids {
            if var p = self.promptLookup[id] {
                p.deletedAt = now
                p.modifiedAt = now
                immediateUpdates.append(p)
            }
        }
        self.applyUpdatedPromptsToInMemoryState(immediateUpdates)
        
        let nsuuids = ids.map { $0 as NSUUID }
        
        // 2. Offload save processing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let bgContext = self.dataController.container.newBackgroundContext()
            
            bgContext.performAndWait {
                let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id IN %@", nsuuids)
                
                do {
                    let entities = try bgContext.fetch(request)
                    for entity in entities {
                        entity.deletedAt = now
                        entity.modifiedAt = now
                    }
                    if bgContext.hasChanges { try bgContext.save() }
                } catch {
                    print("Error batch deleting in background: \(error)")
                }
            }
        }
        
        return true
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
            var updatedPrompts: [Prompt] = []
            for entity in entities {
                entity.folder = folderName
                entity.modifiedAt = now
                updatedPrompts.append(entity.toPrompt())
            }
            dataController.save()
            applyUpdatedPromptsToInMemoryState(updatedPrompts)
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
            var updatedPrompts: [Prompt] = []
            for entity in entities {
                entity.isFavorite = true
                entity.modifiedAt = now
                updatedPrompts.append(entity.toPrompt())
            }
            dataController.save()
            applyUpdatedPromptsToInMemoryState(updatedPrompts)
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
        PromptRepository.shared.purgeExpiredTrash()
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
        searchEngine.filterPrompts(
            prompts: self.prompts,
            query: query,
            categoryOverride: categoryOverride,
            selectedCategory: self.selectedCategory,
            activeAppBundleID: self.activeAppBundleID,
            promptSortMode: self.promptSortMode
        ) { [weak self] filtered in
            self?.filteredPrompts = filtered
        }
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
    

    private lazy var exportService: PromptExportService = {
        PromptExportService(dataController: dataController, promptService: self)
    }()
    
    func exportAllPrompts() -> String { exportService.exportAllPrompts() }
    func exportAllPromptsAsJSON() -> Data? { exportService.exportAllPromptsAsJSON() }
    func exportBackupZip(to destinationZipURL: URL) -> Bool { exportService.exportBackupZip(to: destinationZipURL) }
    func importBackupZip(from zipURL: URL) -> (success: Int, failed: Int, foldersCreated: Int) { exportService.importBackupZip(from: zipURL) }
    func exportAllPromptsAsCSV() -> Data? { exportService.exportAllPromptsAsCSV() }
    func importPromptsFromData(_ data: Data) -> (success: Int, failed: Int, foldersCreated: Int) { exportService.importPromptsFromData(data) }
    
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
            UserDefaults.standard.removeObject(forKey: "hasSeededDefaultsV28")
            UserDefaults.standard.removeObject(forKey: "hasSeededInitialPromptsV28")
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
