//
//  SearchViewSimple+Actions.swift
//  Promtier
//
//  Responsabilidad: Lógica de acciones sobre Prompts (usar, copiar, borrar,
//  favoritos, fork, exportar e importar desde archivo).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension SearchViewSimple {

    // MARK: - Use / Copy

    func usePrompt(_ prompt: Prompt) {
        if prompt.hasTemplateVariables() || prompt.hasChains() {
            if prompt.isSmartOnly() && !prompt.hasChains() {
                let resolved = PlaceholderResolver.shared.resolveAll(in: prompt.content)
                promptService.usePrompt(prompt, contentOverride: resolved)
            } else {
                closePreviewImmediately(playSound: false)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { fillingVariablesFor = prompt }
                return
            }
        } else {
            promptService.usePrompt(prompt)
        }
        triggerCopyFeedback()
        closePreviewImmediately(playSound: false)
        scheduleCloseIfNeeded()
    }

    func copyPromptPack(_ prompt: Prompt) {
        copyPrompt(prompt, as: .pack)
    }

    func copyPrompt(_ prompt: Prompt, as format: PromptCopyFormat) {
        let content = promptPackMarkdown(for: prompt, format: format)

        switch format {
        case .markdown, .pack:
            ClipboardService.shared.copyToClipboard(content)
        case .plainText:
            let plain = MarkdownRTFConverter.parseMarkdown(
                content, baseFont: .systemFont(ofSize: 14), textColor: .labelColor
            ).string
            ClipboardService.shared.copyToClipboard(plain)
        case .richText:
            let attributed = MarkdownRTFConverter.parseMarkdown(
                content, baseFont: .systemFont(ofSize: 14), textColor: .labelColor
            )
            ClipboardService.shared.copyRichTextToClipboard(attributed)
        }

        promptService.recordPromptUse(prompt)
        triggerCopyFeedback()
        closePreviewImmediately(playSound: false)
        scheduleCloseIfNeeded()
    }

    // MARK: - CRUD Actions

    func toggleFavorite(_ prompt: Prompt) {
        var updated = latestPrompt(for: prompt)
        updated.isFavorite.toggle()
        _ = promptService.updatePrompt(updated)
        if selectedPrompt?.id == updated.id { selectedPrompt = updated }
        if preferences.soundEnabled { SoundService.shared.playFavoriteSound() }
        HapticService.shared.playImpact()
    }

    func deletePrompt(_ prompt: Prompt) {
        if batchService.isSelectionModeActive,
           batchService.selectedPromptIds.contains(prompt.id),
           batchService.selectedPromptIds.count > 1 {
            _ = promptService.deletePrompts(withIds: Array(batchService.selectedPromptIds))
            withAnimation(.spring()) { batchService.clearSelection() }
        } else {
            _ = promptService.deletePrompt(prompt)
            if batchService.isSelectionModeActive { batchService.selectedPromptIds.remove(prompt.id) }
        }
        if preferences.soundEnabled { SoundService.shared.playDeleteSound() }
    }

    func forkPrompt(_ prompt: Prompt) {
        closePreviewImmediately(playSound: false)
        menuBarManager.showWithState(.newPrompt)

        var forked = prompt
        forked.id = UUID()
        forked.title = prompt.title + " (Copy)"
        forked.createdAt = Date()
        forked.modifiedAt = Date()
        forked.useCount = 0
        forked.lastUsedAt = nil
        forked.isFavorite = false

        DraftService.shared.saveDraft(prompt: forked, isEditing: false)
    }

    func exportPromptsToFile(_ prompt: Prompt) {
        let content = "\(prompt.title)\n\n\(prompt.content)"
        let fileName = "\(prompt.title.replacingOccurrences(of: " ", with: "_")).txt"
        let savePanel = NSSavePanel()
        if let txtType = UTType(filenameExtension: "txt") { savePanel.allowedContentTypes = [txtType, .plainText] }
        else { savePanel.allowedContentTypes = [.plainText] }
        savePanel.nameFieldStringValue = fileName
        savePanel.title = "export_prompts_title".localized(for: preferences.language)
        savePanel.message = "export_prompts_message".localized(for: preferences.language)
        NSApp.activate(ignoringOtherApps: true)
        menuBarManager.closePopover()
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do { try content.write(to: url, atomically: true, encoding: .utf8) }
            catch {
                let alert = NSAlert()
                alert.messageText = "export_error_title".localized(for: preferences.language)
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    // MARK: - Prompt Pack Formatting

    func promptPackMarkdown(for prompt: Prompt, format: PromptCopyFormat = .pack) -> String {
        guard format == .pack else { return prompt.content }

        var parts: [String] = [prompt.content]

        if let negative = prompt.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !negative.isEmpty {
            let title = "negative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(negative)")
        }

        for (index, alt) in prompt.alternatives.enumerated() {
            let trimmed = alt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let title = "\("alternative".localized(for: preferences.language)) #\(index + 1)"
                parts.append("\n\n\(title):\n\(trimmed)")
            }
        }

        if prompt.alternatives.isEmpty,
           let alt = prompt.alternativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !alt.isEmpty {
            let title = "alternative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(alt)")
        }

        return parts.joined()
    }

    // MARK: - Hover Handling

    func handlePromptHover(_ prompt: Prompt, isHovering: Bool) {
        hoverPrewarmCoordinator.handleHover(prompt: prompt, isHovering: isHovering) { hoveredPrompt in
            let latest = self.latestPrompt(for: hoveredPrompt)
            self.prewarmPreviewAssets(for: latest)
        }
    }

    // MARK: - Feedback Helpers

    func triggerCopyFeedback() {
        if preferences.soundEnabled { SoundService.shared.playCopySound() }
        HapticService.shared.playAlignment()
        if preferences.isPremiumActive && preferences.visualEffectsEnabled {
            showParticles = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.showParticles = true }
        }
    }

    func scheduleCloseIfNeeded() {
        guard preferences.closeOnCopy else { return }
        if preferences.isPremiumActive && preferences.visualEffectsEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.menuBarManager.closePopover() }
        } else {
            menuBarManager.closePopover()
        }
    }
}
