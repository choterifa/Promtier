//
//  SearchViewSimple+Presentation.swift
//  Promtier
//
//  Responsabilidad: Lógica de presentación pura — cálculo de colores de categoría,
//  íconos resueltos, constructor de cards y context menus.
//

import SwiftUI

extension SearchViewSimple {

    // MARK: - Category Presentation

    var isPerformanceCardMode: Bool {
        let count = promptService.filteredPrompts.count
        return count >= 72
    }

    func categoryColor(for prompt: Prompt) -> Color {
        guard let folderName = prompt.folder, !folderName.isEmpty else { return .blue }
        if let folder = folderPresentationByName[folderName] { return folder.color }
        return PredefinedCategory.fromString(folderName)?.color ?? .blue
    }

    func resolvedIcon(for prompt: Prompt) -> String {
        if let customIcon = prompt.icon, !customIcon.isEmpty { return customIcon }
        guard let folderName = prompt.folder, !folderName.isEmpty else { return "doc.text.fill" }
        if let folder = folderPresentationByName[folderName] { return folder.icon ?? "folder.fill" }
        return PredefinedCategory.fromString(folderName)?.icon ?? "folder.fill"
    }

    // MARK: - Card Builders

    @ViewBuilder
    func promptGridCard(for prompt: Prompt) -> some View {
        let color = categoryColor(for: prompt)
        previewPopoverIfSelected(for: prompt) {
            PromptGridCard(
                prompt: prompt,
                precomputedCategoryColor: color,
                isPerformanceMode: isPerformanceCardMode,
                isSelected: selectedPrompt?.id == prompt.id,
                isHovered: false,
                onTap: { onSelectPrompt(prompt) },
                onDoubleTap: { onDoubleTapPrompt(prompt) },
                onCopy: { usePrompt(prompt) },
                onHover: { hovering in handlePromptHover(prompt, isHovering: hovering) }
            )
            .contextMenu { promptContextMenu(for: prompt) }
        }
    }

    @ViewBuilder
    func promptRow(for prompt: Prompt) -> some View {
        let color = categoryColor(for: prompt)
        let icon = resolvedIcon(for: prompt)
        previewPopoverIfSelected(for: prompt) {
            PromptCard(
                prompt: prompt,
                precomputedCategoryColor: color,
                precomputedResolvedIcon: icon,
                isPerformanceMode: isPerformanceCardMode,
                isSelected: selectedPrompt?.id == prompt.id,
                isHovered: false,
                onTap: { onSelectPrompt(prompt) },
                onDoubleTap: { onDoubleTapPrompt(prompt) },
                onCopy: { usePrompt(prompt) },
                onCopyPack: { copyPromptPack(prompt) },
                onHover: { hovering in handlePromptHover(prompt, isHovering: hovering) }
            )
            .contextMenu { promptContextMenu(for: prompt) }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    func promptContextMenu(for prompt: Prompt) -> some View {
        let latest = latestPrompt(for: prompt)

        Button {
            usePrompt(latest)
        } label: {
            Label("use_copy".localized(for: preferences.language), systemImage: "doc.on.doc")
        }

        Button {
            copyPromptPack(latest)
        } label: {
            Label("copy_pack".localized(for: preferences.language), systemImage: "doc.on.doc.fill")
        }

        Divider()

        Button {
            openEditorForSelection(prompt: latest)
        } label: {
            Label("edit".localized(for: preferences.language), systemImage: "pencil")
        }

        Button {
            forkPrompt(latest)
        } label: {
            Label("duplicate".localized(for: preferences.language), systemImage: "plus.square.on.square")
        }

        Divider()

        Button {
            toggleFavorite(latest)
        } label: {
            Label(
                latest.isFavorite
                    ? "remove_favorite".localized(for: preferences.language)
                    : "add_favorite".localized(for: preferences.language),
                systemImage: latest.isFavorite ? "star.slash" : "star"
            )
        }

        if let folderName = latest.folder, !folderName.isEmpty {
            Button {
                _ = promptService.movePrompts(withIds: [latest.id], toFolder: nil)
            } label: {
                Label("remove_from_folder".localized(for: preferences.language), systemImage: "folder.badge.minus")
            }
        }

        Divider()

        Button {
            exportPromptsToFile(latest)
        } label: {
            Label("export".localized(for: preferences.language), systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            deletePrompt(latest)
        } label: {
            Label("delete".localized(for: preferences.language), systemImage: "trash")
        }
    }

    // MARK: - Selection Action Helpers

    func onSelectPrompt(_ prompt: Prompt) {
        isSearchFocused = false
        isUserNavigating = false // Detener cualquier auto-scroll al usar el ratón
        let latest = latestPrompt(for: prompt)
        selectedPrompt = latest
        prewarmPreviewAssets(for: latest)
        if showingPreview { refreshPreviewPrefetchIfNeeded(for: latest) }
        if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
    }

    func onDoubleTapPrompt(_ prompt: Prompt) {
        isUserNavigating = false
        selectedPrompt = latestPrompt(for: prompt)
        withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
    }

    func openEditorForSelection(prompt: Prompt? = nil) {
        let target = prompt ?? selectedPrompt
        guard target != nil else { return }
        withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
    }
}
