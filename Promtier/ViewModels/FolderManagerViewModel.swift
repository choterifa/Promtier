//
//  FolderManagerViewModel.swift
//  Promtier
//
//  ViewModel para la gestión de categorías
//

import SwiftUI
import Combine

@MainActor
class FolderManagerViewModel: ObservableObject {
    @Published var newFolderName = ""
    @Published var selectedColor: Color = .blue
    @Published var selectedIcon: String? = "folder.fill"
    @Published var selectedParentId: UUID? = nil
    @Published var editingFolder: Folder? = nil
    
    @Published var showingIconPicker = false
    @Published var animateColors = false
    
    // Alertas
    @Published var folderToDelete: Folder? = nil
    @Published var showingDeleteAlert = false
    @Published var showingDuplicateAlert = false
    @Published var showingReservedNameAlert = false
    @Published private(set) var categoryCounts: [String: Int] = [:]

    func refreshCounters(with prompts: [Prompt]) {
        var counts: [String: Int] = [:]
        for prompt in prompts {
            let folder = prompt.folder ?? "uncategorized"
            counts[folder, default: 0] += 1
        }
        if counts != categoryCounts {
            categoryCounts = counts
        }
    }

    func categoryCount(for folderName: String) -> Int {
        categoryCounts[folderName, default: 0]
    }
    
    func startEditing(_ folder: Folder) {
        withAnimation(.spring()) {
            editingFolder = folder
            newFolderName = folder.name
            selectedIcon = folder.icon ?? "folder.fill"
            selectedColor = Color(hex: folder.displayColor)
            selectedParentId = folder.parentId
        }
    }
    
    func resetForm(menuBarManager: MenuBarManager) {
        withAnimation(.spring()) {
            editingFolder = nil
            newFolderName = ""
            selectedColor = .blue
            selectedIcon = "folder.fill"
            selectedParentId = nil
            menuBarManager.folderToEdit = nil
        }
    }
    
    func revertChanges() {
        guard let folder = editingFolder else { return }
        withAnimation(.spring()) {
            newFolderName = folder.name
            selectedIcon = folder.icon ?? "folder.fill"
            selectedColor = Color(hex: folder.displayColor)
            selectedParentId = folder.parentId
        }
    }
    
    func requestDelete(folder: Folder) {
        let count = categoryCount(for: folder.name)
        if count > 0 {
            folderToDelete = folder
            showingDeleteAlert = true
        } else {
            // Delete immediately if empty, this needs to call promptService so we handle it from the View or inject it
        }
    }
    
    func confirmDelete(promptService: PromptService) {
        guard let folder = folderToDelete else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            _ = promptService.deleteFolder(folder)
        }
        HapticService.shared.playSuccess()
    }
    
    func saveFolder(
        promptService: PromptService,
        preferences: PreferencesManager,
        onSuccess: @escaping () -> Void
    ) {
        let sanitizedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Validar nombre reservado
        let reservedNames = [
            "uncategorized", "sin categoría", "uncategorized".localized(for: preferences.language).lowercased()
        ]
        if reservedNames.contains(sanitizedName.lowercased()) {
            showingReservedNameAlert = true
            return
        }
        
        // 2. Validar duplicados
        let isEditingThis = editingFolder?.name.lowercased() == sanitizedName.lowercased()
        let nameExists = promptService.folders.contains { 
            $0.name.lowercased() == sanitizedName.lowercased() 
        }
        
        if nameExists && !isEditingThis {
            showingDuplicateAlert = true
            return
        }
        
        let isAIAvailable = preferences.isPreferredAIServiceConfigured
                            
        // Auto-Magic Icon/Color
        if editingFolder == nil && selectedIcon == "folder.fill" && selectedColor == .blue && isAIAvailable {
            finishSavingFolder(sanitizedName: sanitizedName, iconParam: "folder.fill", parentIdParam: selectedParentId, promptService: promptService, onSuccess: onSuccess)

            let magicPrompt = AIServiceManager.generateCategoryIconAndColorPrompt(categoryName: sanitizedName)
            let allowedIcons = Set(Theme.Icons.allIconNames)
            
            Task.detached {
                struct MagicResponse: Codable {
                    let icon: String
                    let color: String
                }

                do {
                    let fullResponse = try await AIServiceManager.shared.generate(prompt: magicPrompt, imageData: nil)
                    
                    let cleanResponse = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                    
                    guard let data = cleanResponse.data(using: .utf8),
                          let decoded = try? JSONDecoder().decode(MagicResponse.self, from: data) else { return }
                    
                    let finalIcon = allowedIcons.contains(decoded.icon) ? decoded.icon : "folder.fill"
                    let finalColor = decoded.color.hasPrefix("#") ? decoded.color : "#" + decoded.color
                    
                    await MainActor.run {
                        if let folder = promptService.folders.first(where: { $0.name == sanitizedName }) {
                            var updated = folder
                            updated.icon = finalIcon
                            updated.color = finalColor
                            _ = promptService.updateFolder(updated, oldName: sanitizedName)
                        }
                    }
                } catch { }
            }
        } else if editingFolder == nil && selectedIcon == "folder.fill" && isAIAvailable {
             finishSavingFolder(sanitizedName: sanitizedName, iconParam: "folder.fill", parentIdParam: selectedParentId, promptService: promptService, onSuccess: onSuccess)

             let iconPrompt = AIServiceManager.generateCategoryIconPrompt(categoryName: sanitizedName)
             let allowedIcons = Set(Theme.Icons.allIconNames)

             Task.detached {
                 do {
                     let fullResponse = try await AIServiceManager.shared.generate(prompt: iconPrompt, imageData: nil)
                     let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                     
                     if allowedIcons.contains(result) {
                         await MainActor.run {
                             if let folder = promptService.folders.first(where: { $0.name == sanitizedName }) {
                                 var updated = folder
                                 updated.icon = result
                                 _ = promptService.updateFolder(updated, oldName: sanitizedName)
                             }
                         }
                     }
                 } catch { }
             }
        } else {
            finishSavingFolder(sanitizedName: sanitizedName, iconParam: selectedIcon, parentIdParam: selectedParentId, promptService: promptService, onSuccess: onSuccess)
        }
    }
    
    private func finishSavingFolder(sanitizedName: String, iconParam: String?, parentIdParam: UUID?, promptService: PromptService, onSuccess: @escaping () -> Void) {
        let hex = "#" + NSColor(selectedColor).hexString
        
        if let editing = editingFolder {
            let updated = Folder(id: editing.id, name: sanitizedName, color: hex, icon: iconParam, createdAt: editing.createdAt, parentId: parentIdParam)
            _ = promptService.updateFolder(updated, oldName: editing.name)
        } else {
            let new = Folder(name: sanitizedName, color: hex, icon: iconParam, parentId: parentIdParam)
            _ = promptService.createFolder(new)
        }
        onSuccess()
    }
}
