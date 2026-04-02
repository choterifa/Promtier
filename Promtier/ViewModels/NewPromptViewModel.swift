import SwiftUI
import Combine

@MainActor
final class NewPromptViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var negativePrompt = ""
    @Published var alternatives: [String] = []
    @Published var promptDescription = ""
    @Published var selectedFolder: String?
    @Published var isFavorite = false
    @Published var selectedIcon: String?
    @Published var showcaseImages: [Data] = []
    @Published var isSaving = false
    
    @Published var tags: [String] = []
    @Published var newTag: String = ""
    
    @Published var targetAppBundleIDs: [String] = []
    @Published var customShortcut: String? = nil
    
    @Published var originalPrompt: Prompt?
    
    private var draftHash: Int = 0
    
    var promptId: UUID? {
        originalPrompt?.id
    }
    
    init(prompt: Prompt? = nil, initialFolder: String? = nil) {
        self.originalPrompt = prompt
        
        if let prompt = prompt {
            self.title = prompt.title
            self.content = prompt.content
            self.negativePrompt = prompt.negativePrompt ?? ""
            self.alternatives = prompt.alternatives
            self.promptDescription = prompt.promptDescription ?? ""
            self.selectedFolder = prompt.folder
            self.tags = prompt.tags
            self.isFavorite = prompt.isFavorite
            self.selectedIcon = prompt.icon
            self.showcaseImages = prompt.showcaseImages
            self.targetAppBundleIDs = prompt.targetAppBundleIDs
            self.customShortcut = prompt.customShortcut
        } else if let folder = initialFolder {
            self.selectedFolder = folder
        }
        
        updateDraftHash()
    }
    
    func updateDraftHash() {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(negativePrompt)
        hasher.combine(alternatives)
        hasher.combine(promptDescription)
        hasher.combine(selectedFolder)
        draftHash = hasher.finalize()
    }
    
    func hasUnsavedChanges() -> Bool {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(negativePrompt)
        hasher.combine(alternatives)
        hasher.combine(promptDescription)
        hasher.combine(selectedFolder)
        return draftHash != hasher.finalize()
    }
    
    func savePrompt(promptService: PromptService, onClose: (() -> Void)? = nil) {
        guard !title.isEmpty, !content.isEmpty else { return }
        
        // Setup updated object
        let newNegativePrompt: String? = negativePrompt.isEmpty ? nil : negativePrompt
        
        let existingPrompt = originalPrompt
        if existingPrompt != nil {
            var updated = existingPrompt!
            updated.title = title
            updated.content = content
            updated.promptDescription = promptDescription.isEmpty ? nil : promptDescription
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.icon = selectedIcon
            updated.showcaseImages = showcaseImages
            updated.tags = tags
            updated.negativePrompt = newNegativePrompt
            updated.alternatives = alternatives
            updated.targetAppBundleIDs = targetAppBundleIDs
            updated.customShortcut = customShortcut
            updated.modifiedAt = Date()
            
            _ = promptService.updatePrompt(updated)
            self.originalPrompt = updated
        } else {
            var new = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? nil : promptDescription,
                folder: selectedFolder,
                icon: selectedIcon,
                showcaseImages: showcaseImages,
                tags: tags,
                targetAppBundleIDs: targetAppBundleIDs,
                negativePrompt: newNegativePrompt,
                alternatives: alternatives,
                customShortcut: customShortcut
            )
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
            self.originalPrompt = new
        }
        
        DraftService.shared.clearDraft()
        onClose?()
    }
}
