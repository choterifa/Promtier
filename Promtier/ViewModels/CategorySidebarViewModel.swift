//
//  CategorySidebarViewModel.swift
//  Promtier
//
//  ViewModel para el Sidebar de Categorías
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
class CategorySidebarViewModel: ObservableObject {
    @Published var showingFolderManager = false
    @Published var dropTargetFolderId: UUID? = nil
    @Published var isTargetedFavoritos = false
    @Published var isTargetedSinCategoria = false

    @Published private(set) var categoryCounts: [String: Int] = [:]
    @Published private(set) var recentCount: Int = 0
    @Published private(set) var favoritesCount: Int = 0
    
    // Reordenado (Sidebar)
    @Published var draggedFolder: Folder? = nil
    
    // Alerta de eliminación
    @Published var folderToDelete: Folder? = nil
    @Published var showingDeleteAlert = false
    
    // Header hover states
    @Published var isAddFolderHovered = false
    @Published var isSortMenuHovered = false
    @Published var isHeaderHovered = false
    @Published var isSystemSectionExpanded = true
    
    func refreshCounters(with prompts: [Prompt]) {
        var counts: [String: Int] = [:]
        var recent = 0
        var favorites = 0

        for prompt in prompts {
            let folder = prompt.folder ?? "uncategorized"
            counts[folder, default: 0] += 1

            if prompt.lastUsedAt != nil {
                recent += 1
            }
            if prompt.isFavorite {
                favorites += 1
            }
        }

        categoryCounts = counts
        recentCount = recent
        favoritesCount = favorites
    }

    func categoryCount(for folderName: String) -> Int {
        categoryCounts[folderName, default: 0]
    }
    
    func movePrompt(id: String, to folderName: String?, promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) {
        movePrompts(ids: [id], to: folderName, promptService: promptService, batchService: batchService, preferences: preferences)
    }

    func movePrompts(ids: [String], to folderName: String?, promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        
        if preferences.soundEnabled { SoundService.shared.playMoveSound() }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        _ = promptService.movePrompts(withIds: uuids, toFolder: folderName)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
    }
    
    func markAsFavorite(ids: [String], promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        
        if preferences.soundEnabled { SoundService.shared.playFavoriteSound() }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        _ = promptService.markPromptsFavorite(withIds: uuids)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
    }

    func markAsFavorite(id: String, promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) {
        markAsFavorite(ids: [id], promptService: promptService, batchService: batchService, preferences: preferences)
    }

    func moveToTrash(ids: [String], promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        
        if preferences.soundEnabled { SoundService.shared.playDeleteSound() }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        _ = promptService.deletePrompts(withIds: uuids)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
    }
    
    func decodeDraggedPromptIds(from provider: NSItemProvider, completion: @escaping ([String]) -> Void) -> Bool {
        let jsonType = UTType.json.identifier
        guard provider.hasItemConformingToTypeIdentifier(jsonType) else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: jsonType) { data, _ in
            Task { @MainActor in
                guard let data,
                      let payload = try? JSONDecoder().decode(SidebarDragPayload.self, from: data),
                      payload.kind == "promtier.prompt.ids",
                      let ids = payload.ids,
                      !ids.isEmpty else { return }
                completion(ids)
            }
        }
        return true
    }
    
    func handleQuickDrop(providers: [NSItemProvider], to category: String?, promptService: PromptService, batchService: BatchOperationsService, preferences: PreferencesManager) -> Bool {
        for provider in providers {
            if decodeDraggedPromptIds(from: provider, completion: { ids in
                DispatchQueue.main.async {
                    if category == "favorites" {
                        self.markAsFavorite(ids: ids, promptService: promptService, batchService: batchService, preferences: preferences)
                    } else if category == "trash" {
                        self.moveToTrash(ids: ids, promptService: promptService, batchService: batchService, preferences: preferences)
                    } else {
                        self.movePrompts(ids: ids, to: category, promptService: promptService, batchService: batchService, preferences: preferences)
                    }
                }
            }) {
                return true
            }
        }
        return false
    }
    
    func requestDelete(folder: Folder, counts: [String: Int]) {
        let count = counts[folder.name] ?? 0
        if count > 0 {
            folderToDelete = folder
            showingDeleteAlert = true
        } else {
            // Se debe manejar desde la vista inyectando promptService o devolviendo un booleano
        }
    }
    
    func confirmDelete(promptService: PromptService) {
        guard let folder = folderToDelete else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            _ = promptService.deleteFolder(folder)
        }
        HapticService.shared.playSuccess()
    }
}
