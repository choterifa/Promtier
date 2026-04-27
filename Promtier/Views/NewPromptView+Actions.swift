import SwiftUI
import AppKit

extension NewPromptView {

    func applyLoadedPromptState(from source: Prompt, markDraftRestored: Bool = false) {
        title = source.title
        content = source.content
        negativePrompt = source.negativePrompt ?? ""
        alternatives = normalizedAlternatives(from: source)
        alternativeDescriptions = normalizedAlternativeDescriptions(from: source, for: alternatives)
        promptDescription = source.promptDescription ?? ""
        selectedFolder = source.folder
        isFavorite = source.isFavorite
        selectedIcon = source.icon
        showcaseImages = source.showcaseImages
        mediaState.clampSelection(for: showcaseImages)
        tags = source.tags
        targetAppBundleIDs = source.targetAppBundleIDs
        customShortcut = source.customShortcut
        showNegativeField = !negativePrompt.isEmpty
        showAlternativeField = !alternatives.isEmpty
        isDraftRestored = markDraftRestored
        syncAlternativeDescriptionsWithAlternatives()
        syncHoistedFieldsToViewModel()
    }

    func setupOnAppear() {
        MenuBarManager.shared.isModalActive = false

        let draft = DraftService.shared.loadDraft()

        var shouldLoadDraft = false
        if let draft = draft {
            if prompt == nil {
                shouldLoadDraft = true
            } else if let prompt = prompt, draft.prompt.id == prompt.id {
                shouldLoadDraft = true
            } else if draft.isEditing {
                shouldLoadDraft = true
            }
        }

        if shouldLoadDraft, let draft = draft {
            let draftPrompt = draft.prompt

            if draft.isEditing {
                if let original = promptService.prompts.first(where: { $0.id == draftPrompt.id }) {
                    originalPrompt = original
                } else if let prompt {
                    originalPrompt = prompt
                }
            }

            DispatchQueue.main.async {
                self.applyLoadedPromptState(from: draftPrompt, markDraftRestored: true)
            }

        } else if let prompt {
            originalPrompt = prompt
            applyLoadedPromptState(from: prompt)

            if showcaseImages.isEmpty && prompt.showcaseImageCount > 0 {
                Task(priority: .userInitiated) {
                    if let full = await promptService.fetchPrompt(byId: prompt.id, includeImages: true) {
                        await MainActor.run {
                            self.originalPrompt = full
                            if self.showcaseImages.isEmpty {
                                self.showcaseImages = full.showcaseImages
                                self.mediaState.clampSelection(for: self.showcaseImages)
                            }
                        }
                    }
                }
            }
        } else if let activeCategory = promptService.selectedCategory {
            selectedFolder = activeCategory
        }
    }

    func saveCurrentDraft() {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isContentTextEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if originalPrompt == nil && isTitleEmpty && isContentTextEmpty {
            return
        }

        if !hasUnsavedChanges {
            return
        }

        var draftPrompt = Prompt(
            title: title,
            content: content,
            promptDescription: promptDescription.isEmpty ? nil : promptDescription,
            folder: selectedFolder,
            icon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            targetAppBundleIDs: targetAppBundleIDs,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            alternatives: alternatives,
            alternativeDescriptions: alternativeDescriptions,
            customShortcut: customShortcut
        )

        if let original = originalPrompt {
            draftPrompt.id = original.id
        }

        DraftService.shared.saveDraft(prompt: draftPrompt, isEditing: prompt != nil || originalPrompt != nil)
    }

    func appendOptimizedImageData(_ rawData: Data, at index: Int?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PromptMediaImportPipeline.optimizeImageData(rawData)
            switch result {
            case .failure(let failure):
                self.showImageImportWarning(PromptMediaImportPipeline.localizedMessage(for: failure, language: self.preferences.language))
            case .success(let optimizedData):
                DispatchQueue.main.async {
                    self.insertImage(optimizedData, at: index)
                }
            }
        }
    }

    func showImageImportWarning(_ message: String) {
        DispatchQueue.main.async {
            HapticService.shared.playError()
            withAnimation {
                self.branchMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                    if self.branchMessage == message {
                        self.branchMessage = nil
                    }
                }
            }
        }
    }

    func insertImage(_ data: Data, at index: Int?) {
        if PromptMediaImportPipeline.insertImage(data, at: index, into: &showcaseImages, mediaState: &mediaState) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    func closeAfterSuccessfulSave() {
        if preferences.isPremiumActive && preferences.visualEffectsEnabled {
            showParticles = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.onClose()
            }
            return
        }
        onClose()
    }

    func savePrompt(closeAfter: Bool = true) {
        isSaving = true

        if closeAfter {
            DraftService.shared.clearDraft()
            MenuBarManager.shared.isModalActive = false
        }

        let newNegativePrompt = normalizedNegativePrompt

        if let existingPrompt = originalPrompt ?? prompt {
            if !hasBasicPromptChanges(comparedTo: existingPrompt, newNegativePrompt: newNegativePrompt) {
                if closeAfter { onClose() }
                return
            }

            var updated = existingPrompt

            appendVersionSnapshotIfNeeded(to: &updated, from: existingPrompt, newNegativePrompt: newNegativePrompt)
            applyEditableFields(to: &updated, newNegativePrompt: newNegativePrompt)
            _ = promptService.updatePrompt(updated)
            
            DispatchQueue.main.async {
                self.originalPrompt = updated
            }
        } else {
            var new = Prompt(
                title: title,
                content: content,
                promptDescription: normalizedPromptDescription,
                folder: selectedFolder,
                icon: selectedIcon,
                showcaseImages: showcaseImages,
                tags: tags,
                targetAppBundleIDs: targetAppBundleIDs,
                negativePrompt: newNegativePrompt,
                alternatives: alternatives,
                alternativeDescriptions: alternativeDescriptions,
                customShortcut: customShortcut
            )
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
        }

        if closeAfter {
            closeAfterSuccessfulSave()
        }
    }

    func branchPrompt() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let branchTitle = "\("branch_label".localized(for: preferences.language)): \(title)"
        let newContent = content
        let currentParentID = (originalPrompt ?? prompt)?.id

        var newBranch = Prompt(
            title: branchTitle,
            content: newContent,
            promptDescription: promptDescription,
            folder: selectedFolder,
            icon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            targetAppBundleIDs: targetAppBundleIDs,
            negativePrompt: negativePrompt,
            alternatives: Array(alternatives.prefix(10)),
            customShortcut: nil
        )

        newBranch.parentID = currentParentID
        newBranch.isFavorite = isFavorite

        if promptService.createPrompt(newBranch) {
            HapticService.shared.playSuccess()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                branchMessage = "branch_created_success".localized(for: preferences.language)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { self.branchMessage = nil }
                
                DraftService.shared.clearDraft()
                
                self.promptService.searchQuery = ""
                if let folder = self.selectedFolder {
                    self.promptService.selectedCategory = folder
                } else {
                    self.promptService.selectedCategory = nil
                }
                
                MenuBarManager.shared.isModalActive = false
                self.onClose()
            }
        }
    }

    func syncHoistedFieldsToViewModel() {
        viewModel.title = titleHoister.fastText
        viewModel.content = contentHoister.fastText
        viewModel.promptDescription = promptDescriptionHoister.fastText
    }

    func syncHoistedFieldsFromViewModel() {
        titleHoister.setExternal(viewModel.title)
        contentHoister.setExternal(viewModel.content)
        promptDescriptionHoister.setExternal(viewModel.promptDescription)
    }

    func syncAlternativeDescriptionsWithAlternatives() {
        if alternativeDescriptions.count < alternatives.count {
            alternativeDescriptions.append(contentsOf: Array(repeating: "", count: alternatives.count - alternativeDescriptions.count))
        } else if alternativeDescriptions.count > alternatives.count {
            alternativeDescriptions = Array(alternativeDescriptions.prefix(alternatives.count))
        }
        viewModel.alternativeDescriptions = alternativeDescriptions
    }

    func autocompletePromptContent() {
        syncHoistedFieldsToViewModel()
        viewModel.autocompletePromptContent(preferences: preferences, promptService: promptService)
    }

    func executeAutocomplete(keepContent: Bool) {
        syncHoistedFieldsToViewModel()
        viewModel.executeAutocomplete(preferences: preferences, promptService: promptService, keepContent: keepContent)
    }

    func executeMagicWithCommand() {
        syncHoistedFieldsToViewModel()
        viewModel.executeMagicWithCommand(preferences: preferences)
    }

    func autoCategorizePrompt() {
        syncHoistedFieldsToViewModel()
        viewModel.autoCategorizePrompt(preferences: preferences, promptService: promptService)
    }

    func generateAlternativeDirect() {
        syncHoistedFieldsToViewModel()
        viewModel.generateAlternativeDirect(preferences: preferences)
    }

    func saveAsDraft() {
        if originalPrompt == nil {
            if title.isEmpty {
                let prefix = "draft_prefix".localized(for: preferences.language)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: preferences.language.rawValue)
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                title = "\(prefix) - \(formatter.string(from: Date()))"
            }
            selectedFolder = nil
        }
        savePrompt(closeAfter: true)
    }

    func discardChanges() {
        isDiscarding = true
        DraftService.shared.clearDraft()
        MenuBarManager.shared.isModalActive = false
        onClose()
    }

    func dismissSnippetsOverlay() {
        withAnimation { showSnippets = false }
    }

    func dismissVariablesOverlay() {
        withAnimation { showVariables = false }
    }

    func showTransientBranchMessage(_ message: String, duration: TimeInterval = 2.0) {
        withAnimation(.spring()) {
            branchMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation {
                if branchMessage == message {
                    branchMessage = nil
                }
            }
        }
    }

    func isTextSelectedInEditor() -> Bool {
        guard let window = NSApp.keyWindow,
              let fieldEditor = window.firstResponder as? NSTextView,
              fieldEditor.selectedRange().length > 0 else {
            return false
        }
        return true
    }

    @ViewBuilder
    func helpPopover(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.localized(for: preferences.language))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(content.localized(for: preferences.language))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(width: 250)
    }
}
