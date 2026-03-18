import SwiftUI
import Combine

class BatchOperationsService: ObservableObject {
    @Published var selectedPromptIds: Set<UUID> = []
    @Published var isSelectionModeActive: Bool = false
    
    func toggleSelection(for id: UUID) {
        if selectedPromptIds.contains(id) {
            selectedPromptIds.remove(id)
        } else {
            selectedPromptIds.insert(id)
        }
    }
    
    func clearSelection() {
        selectedPromptIds.removeAll()
        isSelectionModeActive = false
    }
    
    func selectAll(from prompts: [Prompt]) {
        selectedPromptIds = Set(prompts.map { $0.id })
    }
}
