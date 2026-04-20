//
//  PromptService.swift
//  Promtier
//
//  ORQUESTADOR DE ESTADO: Gestiona el estado publicado de la UI y delega
//  todas las operaciones de persistencia a PromptRepository.
//
//  Created by Carlos on 15/03/26.
//

import Foundation
@preconcurrency import CoreData
import Combine
import SwiftUI

class PromptService: ObservableObject {
    static let shared = PromptService()

    // MARK: - Nested Types

    enum ShowcaseImageLoadPolicy {
        static let runtimeMaxImages = 3
        static let runtimeMaxTotalBytes = 24 * 1024 * 1024
    }

    enum FolderSortMode: String, Codable, CaseIterable {
        case name, newest
    }

    enum PromptSortMode: String, Codable, CaseIterable {
        case name, newest, mostUsed
    }

    // MARK: - Published State

    @Published var prompts: [Prompt] = []
    @Published var filteredPrompts: [Prompt] = []
    @Published var trashedPrompts: [Prompt] = []
    @Published var folders: [Folder] = []
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String? = nil
    @Published var isLoading: Bool = false
    @Published var activeAppBundleID: String? = nil

    @Published var folderSortMode: FolderSortMode = .newest {
        didSet {
            UserDefaults.standard.set(folderSortMode.rawValue, forKey: "folderSortMode_preference")
            loadFolders()
        }
    }

    @Published var promptSortMode: PromptSortMode = .newest {
        didSet {
            UserDefaults.standard.set(promptSortMode.rawValue, forKey: "promptSortMode_preference")
            filterPrompts(query: searchQuery)
        }
    }

    // MARK: - Private Dependencies

    let searchEngine = PromptSearchEngine()
    private let dataController = DataController.shared
    private let clipboardService = ClipboardService.shared

    private var cancellables = Set<AnyCancellable>()
    private var promptLookup: [UUID: Prompt] = [:]

    private lazy var exportService: PromptExportService = {
        PromptExportService(dataController: dataController, promptService: self)
    }()

    // MARK: - Initializer

    init() {
        restorePreferences()
        bindReactiveFiltering()

        let repo = PromptRepository.shared
        repo.onDataChanged = { [weak self] in
            DispatchQueue.main.async { self?.loadPrompts() }
        }

        seedDefaultFolders()
        repo.removeDuplicatePrompts()
        seedDefaultPrompts()
        repo.purgeExpiredTrash()
        loadFolders()
        loadPrompts()
        repo.migrateShowcaseImageCountIfNeeded()
        repo.migrateShowcaseBlobsToDiskIfNeeded()
        repo.repairMissingShowcaseReferencesIfNeeded()
    }

    // MARK: - Setup Helpers

    private func restorePreferences() {
        if let raw = UserDefaults.standard.string(forKey: "folderSortMode_preference"),
           let mode = FolderSortMode(rawValue: raw) { folderSortMode = mode }
        if let raw = UserDefaults.standard.string(forKey: "promptSortMode_preference"),
           let mode = PromptSortMode(rawValue: raw) { promptSortMode = mode }
    }

    private func bindReactiveFiltering() {
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] query in self?.filterPrompts(query: query) }
            .store(in: &cancellables)

        $selectedCategory
            .sink { [weak self] cat in
                self?.filterPrompts(query: self?.searchQuery ?? "", categoryOverride: cat)
            }
            .store(in: &cancellables)
    }

    // MARK: - Seeding (Startup, done once per version)

    private func seedDefaultFolders() {
        let context = dataController.viewContext
        let seedKey = "hasSeededDefaultsV28"
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        let request = FolderEntity.fetchAll(in: context)
        guard let entities = try? context.fetch(request) else { return }
        let existingNames = entities.map { $0.name }

        var seeded = 0
        for cat in PredefinedCategory.allCases where !existingNames.contains(cat.displayName) {
            let folder = Folder(id: UUID(), name: cat.displayName, color: cat.hexColor,
                                icon: cat.icon, createdAt: Date(), parentId: nil)
            _ = FolderEntity.create(from: folder, in: context)
            seeded += 1
        }

        if seeded > 0 {
            dataController.save()
            print("✅ \(seeded) categorías base añadidas.")
        }
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    private func seedDefaultPrompts() {
        let context = dataController.viewContext
        let seedKey = "hasSeededInitialPromptsV28"
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        let language = PreferencesManager.shared.language

        func promptExists(id: UUID) -> Bool {
            let req: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return (try? context.count(for: req)) ?? 0 > 0
        }

        let seeds: [(id: String, titleKey: String, contentKey: String,
                      category: PredefinedCategory, extras: (Prompt) -> Prompt)] = [
            ("88888888-8888-4444-AAAA-000000000001", "default_prompt_chatgpt_title",
             "default_prompt_chatgpt_content", .chatGPT, { p in
                 var p = p; p.targetAppBundleIDs = ["com.apple.Safari"]; return p }),
            ("88888888-8888-4444-AAAA-000000000002", "default_prompt_claude_title",
             "default_prompt_claude_content", .claude, { p in
                 var p = p; p.customShortcut = "review"; return p }),
            ("88888888-8888-4444-AAAA-000000000003", "default_prompt_cursor_title",
             "default_prompt_cursor_content", .cursor, { p in
                 var p = p; p.negativePrompt = "default_negative_cursor".localized(for: language); return p }),
            ("88888888-8888-4444-AAAA-000000000004", "default_prompt_midjourney_title",
             "default_prompt_midjourney_content", .midjourney, { p in
                 var p = p
                 p.versionHistory = [
                     PromptSnapshot(id: UUID(), title: p.title,
                                    content: "Initial cinematic prompt",
                                    timestamp: Date().addingTimeInterval(-86400)),
                     PromptSnapshot(id: UUID(), title: p.title,
                                    content: "Added --v 6.0 and lighting details",
                                    timestamp: Date().addingTimeInterval(-3600))
                 ]
                 return p }),
            ("88888888-8888-4444-AAAA-000000000005", "default_prompt_images_title",
             "default_prompt_images_content", .imagesPrompts, { p in
                 var p = p; p.negativePrompt = "default_negative_otaku".localized(for: language); return p })
        ]

        for seed in seeds {
            guard let uuid = UUID(uuidString: seed.id), !promptExists(id: uuid) else { continue }
            var prompt = Prompt(title: seed.titleKey.localized(for: language),
                                content: seed.contentKey.localized(for: language),
                                folder: seed.category.displayName, icon: seed.category.icon)
            prompt.id = uuid
            prompt = seed.extras(prompt)
            _ = PromptEntity.create(from: prompt, in: context)
        }

        dataController.save()
        UserDefaults.standard.set(true, forKey: seedKey)
        loadPrompts()
    }

    // MARK: - Loading

    func loadPrompts() {
        DispatchQueue.main.async { self.isLoading = true }
        let trashDict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = PromptRepository.shared.fetchPromptSummaries(trashDict: trashDict)

            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Error cargando prompts: \(error)")
                    self.isLoading = false
                case .success(let all):
                    self.prompts = all.filter { !$0.isInTrash }
                    self.trashedPrompts = all.filter { $0.isInTrash }
                        .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
                    self.rebuildLookup(with: self.prompts)
                    self.filterPrompts(query: self.searchQuery)
                    ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
                    self.isLoading = false
                }
            }
        }
    }

    func loadFolders() {
        let sorted = PromptRepository.shared.fetchFolders(sortMode: folderSortMode)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.folders = sorted
            }
        }
    }

    // MARK: - In-Memory Lookup

    private func rebuildLookup(with prompts: [Prompt]) {
        var lookup: [UUID: Prompt] = [:]
        lookup.reserveCapacity(prompts.count)
        for p in prompts { lookup[p.id] = p }
        promptLookup = lookup
        searchEngine.rebuildPromptIndices(with: prompts)
    }

    func promptSnapshot(byId id: UUID) -> Prompt? { promptLookup[id] }

    // MARK: - Filtering

    private func filterPrompts(query: String, categoryOverride: String? = "USE_CURRENT") {
        searchEngine.filterPrompts(
            prompts: prompts,
            query: query,
            categoryOverride: categoryOverride,
            selectedCategory: selectedCategory,
            activeAppBundleID: activeAppBundleID,
            promptSortMode: promptSortMode
        ) { [weak self] filtered in
            self?.filteredPrompts = filtered
        }
    }

    // MARK: - Image Loading (delegates to Repository)

    func loadShowcaseImages(from paths: [String],
                            maxImages: Int = ShowcaseImageLoadPolicy.runtimeMaxImages,
                            maxTotalBytes: Int? = nil) -> [Data] {
        PromptRepository.shared.loadShowcaseImages(from: paths, maxImages: maxImages, maxTotalBytes: maxTotalBytes)
    }

    func applyShowcaseImages(_ images: [Data], to entity: PromptEntity,
                             promptId: UUID, clearExisting: Bool) {
        PromptRepository.shared.applyShowcaseImages(images, to: entity,
                                                     promptId: promptId, clearExisting: clearExisting)
    }

    // MARK: - Prompt CRUD (delegates, then refreshes state)

    func fetchPrompt(byId id: UUID, includeImages: Bool) async -> Prompt? {
        await PromptRepository.shared.fetchPrompt(byId: id, includeImages: includeImages)
    }

    func fetchShowcaseImages(byId id: UUID) async -> [Data] {
        await PromptRepository.shared.fetchShowcaseImages(byId: id)
    }

    func fetchShowcaseImagePaths(byId id: UUID) async -> [String] {
        await PromptRepository.shared.fetchShowcaseImagePaths(byId: id)
    }

    func createPrompt(_ prompt: Prompt) -> Bool {
        let ok = PromptRepository.shared.createPrompt(prompt)
        if ok { loadPrompts() }
        return ok
    }

    func updatePrompt(_ prompt: Prompt) -> Bool {
        let ok = PromptRepository.shared.updatePrompt(prompt)
        if ok { applyUpdatedPromptToState(prompt) }
        return ok
    }

    func updateShowcaseImages(promptId: UUID, images: [Data]) async -> Bool {
        let ok = await PromptRepository.shared.updateShowcaseImages(promptId: promptId, images: images)
        if ok { DispatchQueue.main.async { self.loadPrompts() } }
        return ok
    }

    func deletePrompt(_ prompt: Prompt) -> Bool {
        let ok = PromptRepository.shared.deletePrompt(withId: prompt.id)
        if ok { loadPrompts() }
        return ok
    }

    func deletePrompts(withIds ids: [UUID]) -> Bool {
        let ok = PromptRepository.shared.deletePrompts(withIds: ids)
        if ok { loadPrompts() }
        return ok
    }

    func movePrompts(withIds ids: [UUID], toFolder folderName: String?) -> Bool {
        let ok = PromptRepository.shared.movePrompts(withIds: ids, toFolder: folderName)
        if ok { loadPrompts() }
        return ok
    }

    func markPromptsFavorite(withIds ids: [UUID]) -> Bool {
        let ok = PromptRepository.shared.markPromptsFavorite(withIds: ids)
        if ok { loadPrompts() }
        return ok
    }

    func restorePrompt(_ prompt: Prompt) -> Bool {
        let ok = PromptRepository.shared.restorePrompt(withId: prompt.id)
        if ok { loadPrompts() }
        return ok
    }

    func permanentlyDeletePrompt(_ prompt: Prompt) -> Bool {
        let ok = PromptRepository.shared.permanentlyDeletePrompt(withId: prompt.id)
        if ok { loadPrompts() }
        return ok
    }

    func emptyTrash() {
        let ids = trashedPrompts.map { $0.id }
        _ = PromptRepository.shared.deletePrompts(withIds: ids)
        // Hard-delete each permanently
        for prompt in trashedPrompts {
            _ = PromptRepository.shared.permanentlyDeletePrompt(withId: prompt.id)
        }
        loadPrompts()
    }

    // MARK: - Folder CRUD (delegates, then refreshes state)

    func reorderFolders(_ folders: [Folder]) {
        self.folders = folders
        PromptRepository.shared.reorderFolders(folders)
    }

    func createFolder(_ folder: Folder) -> Bool {
        let ok = PromptRepository.shared.createFolder(folder)
        if ok { loadFolders() }
        return ok
    }

    func updateFolder(_ folder: Folder, oldName: String? = nil) -> Bool {
        let ok = PromptRepository.shared.updateFolder(folder, oldName: oldName)
        if ok {
            loadFolders()
            if oldName != nil && oldName != folder.name { loadPrompts() }
        }
        return ok
    }

    func deleteFolder(_ folder: Folder) -> Bool {
        let ok = PromptRepository.shared.deleteFolder(withId: folder.id, name: folder.name)
        if ok { loadFolders(); loadPrompts() }
        return ok
    }

    // MARK: - Export / Import (delegates to PromptExportService)

    func exportAllPrompts() -> String            { exportService.exportAllPrompts() }
    func exportAllPromptsAsJSON() -> Data?        { exportService.exportAllPromptsAsJSON() }
    func exportAllPromptsAsCSV() -> Data?         { exportService.exportAllPromptsAsCSV() }
    func exportBackupZip(to url: URL) -> Bool     { exportService.exportBackupZip(to: url) }
    func importBackupZip(from url: URL) -> (success: Int, failed: Int, foldersCreated: Int) {
        exportService.importBackupZip(from: url)
    }
    func importPromptsFromData(_ data: Data) -> (success: Int, failed: Int, foldersCreated: Int) {
        exportService.importPromptsFromData(data)
    }

    // MARK: - Reset

    func resetAllData() {
        PromptRepository.shared.resetAllData(dataController: dataController)
        seedDefaultFolders()
        seedDefaultPrompts()
        loadFolders()
        loadPrompts()
        print("⚠️ Base de datos restablecida completamente")
    }

    // MARK: - Usage Tracking

    func recordPromptUse(_ prompt: Prompt) {
        var updated = prompt
        updated.recordUse()
        _ = updatePrompt(updated)
    }

    func usePrompt(_ prompt: Prompt, contentOverride: String? = nil) {
        recordPromptUse(prompt)
        clipboardService.copyToClipboard(contentOverride ?? prompt.content)
    }

    func usePromptWithVariables(_ prompt: Prompt, variables: [String: String]) {
        var content = prompt.content
        for (key, value) in variables { content = content.replacingOccurrences(of: "{{\(key)}}", with: value) }
        clipboardService.copyToClipboard(content)
        recordPromptUse(prompt)
    }

    // MARK: - Convenience Queries

    func getFavoritePrompts() -> [Prompt] {
        prompts.filter { $0.isFavorite }.sorted { $0.useCount > $1.useCount }
    }

    func getPromptsInFolder(_ folder: String) -> [Prompt] {
        prompts.filter { $0.folder == folder }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func getAllPrompts() -> [Prompt] { prompts }

    func getMostUsedPrompts(limit: Int = 10) -> [Prompt] {
        Array(prompts.sorted { $0.useCount > $1.useCount }.prefix(limit))
    }

    func getRecentlyModifiedPrompts(limit: Int = 10) -> [Prompt] {
        Array(prompts.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(limit))
    }

    func getStatistics() -> (total: Int, favorites: Int, totalUses: Int) {
        (prompts.count, prompts.filter { $0.isFavorite }.count, prompts.reduce(0) { $0 + $1.useCount })
    }

    // MARK: - Private State Helpers

    /// Actualiza el estado en memoria sin forzar una recarga total de CoreData.
    private func applyUpdatedPromptToState(_ updated: Prompt) {
        let apply = { [weak self] in
            guard let self else { return }
            var touched = false

            if updated.isInTrash {
                if let i = self.prompts.firstIndex(where: { $0.id == updated.id }) {
                    self.prompts.remove(at: i); touched = true
                }
                if let i = self.trashedPrompts.firstIndex(where: { $0.id == updated.id }) {
                    self.trashedPrompts[i] = updated
                } else {
                    self.trashedPrompts.append(updated)
                }
                self.trashedPrompts.sort { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
                self.promptLookup.removeValue(forKey: updated.id)
                self.searchEngine.removePromptIndices(for: updated.id)
            } else {
                if let i = self.prompts.firstIndex(where: { $0.id == updated.id }) {
                    self.prompts[i] = updated; touched = true
                } else {
                    self.prompts.append(updated); touched = true
                }
                self.promptLookup[updated.id] = updated
                self.searchEngine.upsertPromptIndices(with: updated)
                if let i = self.trashedPrompts.firstIndex(where: { $0.id == updated.id }) {
                    self.trashedPrompts.remove(at: i); touched = true
                }
            }

            if !touched { self.loadPrompts(); return }

            self.filterPrompts(query: self.searchQuery)
            let prev = self.promptLookup[updated.id]
            if prev?.customShortcut != updated.customShortcut {
                ShortcutManager.shared.registerPromptHotkeys(prompts: self.prompts)
            }
        }

        Thread.isMainThread ? apply() : DispatchQueue.main.async(execute: apply)
    }
}
