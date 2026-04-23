//
//  OmniSearchView.swift
//  Promtier
//
//  VISTA: Buscador global tipo Spotlight
//

import SwiftUI
import AppKit

struct OmniSearchResultItem {
    let id: UUID
    let prompt: Prompt
    let title: String
    let subtitle: String
    let iconName: String
    let categoryName: String?
    let hasVariables: Bool
    let hasNegative: Bool
    let hasAlternatives: Bool
    let categoryColor: Color
    let isRecommended: Bool
}

struct OmniSearchView: View {
    private struct SearchItemPayload {
        let title: String
        let subtitle: String
        let iconName: String
        let categoryName: String?
        let hasVariables: Bool
        let hasNegative: Bool
        let hasAlternatives: Bool
    }

    private struct SearchIndexEntry {
        let prompt: Prompt
        let titleLower: String
        let contentLower: String
        let descLower: String
        let folderLower: String
        let payload: SearchItemPayload
    }

    @EnvironmentObject var manager: OmniSearchManager
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var indexedPrompts: [SearchIndexEntry] = []
    @State private var filteredResults: [OmniSearchResultItem] = []
    @State private var debouncedSearchTask: Task<Void, Never>? = nil
    @State private var visibleResultIndices: Set<Int> = []
    @State private var folderColorByNameCache: [String: Color] = [:]
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra de Búsqueda Premium con distinción visual
            HStack(spacing: 15) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))
                
                TextField("gt_search_prompts".localized(for: preferences.language), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                    .focused($isFocused)
                    .onExitCommand {
                        isFocused = false
                    }
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                        scheduleSearch()
                    }
                    .onSubmit {
                        if !filteredResults.isEmpty {
                            copyAndClose(filteredResults[selectedIndex].prompt)
                        }
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                // Badge de atajo
                Text("Esc")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.1)))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(NSColor.controlBackgroundColor))
            
            if !filteredResults.isEmpty {
                Divider().opacity(0.1)
                
                // Lista de Resultados
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(filteredResults.enumerated()), id: \.element.prompt.id) { index, result in
                                OmniSearchRow(
                                    item: result,
                                    isSelected: selectedIndex == index,
                                    onSelect: {
                                        selectedIndex = index
                                        isFocused = false
                                    },
                                    onCopy: {
                                        copyAndClose(result.prompt)
                                    },
                                    onVisibilityChange: { isVisible in
                                        if isVisible {
                                            visibleResultIndices.insert(index)
                                        } else {
                                            visibleResultIndices.remove(index)
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(12)
                    }
                    .background(Color.black.opacity(0.001))
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            } else if !query.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.2))
                    Text("no_results".localized(for: preferences.language))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
            
            Spacer(minLength: 0)
            
            // Footer Informativo
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("move_selection".localized(for: preferences.language))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "return")
                    Text("copy_and_close".localized(for: preferences.language))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "command")
                    Text("C")
                    Text("copy".localized(for: preferences.language))
                        .opacity(0.8)
                }

                HStack(spacing: 4) {
                    Image(systemName: "command")
                    Text("E")
                    Text("edit_prompt".localized(for: preferences.language))
                        .opacity(0.8)
                }
                
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.6))
            .padding(.horizontal, 25)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.04))
        }
        .frame(width: 650, height: 450, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
            }
        )
        .onAppear {
            rebuildFolderColorCache(from: promptService.folders)
            rebuildSearchIndex(from: promptService.prompts)
            runSearch()

            // Delay extra para asegurar que la ventana es KEY antes de enfocar el TextField
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
        .onReceive(promptService.$prompts) { prompts in
            rebuildSearchIndex(from: prompts)
            runSearch()
        }
        .onReceive(promptService.$folders) { folders in
            rebuildFolderColorCache(from: folders)
            runSearch()
        }
        .onReceive(manager.$commandEvent) { event in
            guard let event else { return }

            switch event.command {
            case .opened:
                query = ""
                selectedIndex = 0
                runSearch()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }

            case .moveDown:
                let count = filteredResults.count
                guard count > 0 else { return }
                if selectedIndex < count - 1 {
                    selectedIndex += 1
                    HapticService.shared.playLight()
                }

            case .moveUp:
                let count = filteredResults.count
                guard count > 0 else { return }
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    HapticService.shared.playLight()
                }

            case .submit, .copy:
                if !filteredResults.isEmpty && selectedIndex < filteredResults.count {
                    copyAndClose(filteredResults[selectedIndex].prompt)
                }

            case .edit:
                if !filteredResults.isEmpty && selectedIndex < filteredResults.count {
                    openEditorAndClose(filteredResults[selectedIndex].prompt)
                }
            }
        }
        .onDisappear {
            debouncedSearchTask?.cancel()
        }
    }

    private func scheduleSearch() {
        debouncedSearchTask?.cancel()
        debouncedSearchTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                runSearch()
            }
        }
    }

    private func rebuildSearchIndex(from prompts: [Prompt]) {
        indexedPrompts = prompts.map { prompt in
            let subtitle: String
            if let desc = prompt.promptDescription, !desc.isEmpty {
                subtitle = desc
            } else {
                subtitle = prompt.content
            }

            let payload = SearchItemPayload(
                title: prompt.title,
                subtitle: subtitle,
                iconName: prompt.icon ?? "doc.text.fill",
                categoryName: prompt.folder,
                hasVariables: prompt.hasTemplateVariables(),
                hasNegative: !(prompt.negativePrompt?.isEmpty ?? true),
                hasAlternatives: !prompt.alternatives.isEmpty || !(prompt.alternativePrompt?.isEmpty ?? true)
            )

            return SearchIndexEntry(
                prompt: prompt,
                titleLower: prompt.title.lowercased(),
                contentLower: prompt.content.lowercased(),
                descLower: (prompt.promptDescription ?? "").lowercased(),
                folderLower: (prompt.folder ?? "").lowercased(),
                payload: payload
            )
        }
    }

    private func rebuildFolderColorCache(from folders: [Folder]) {
        folderColorByNameCache = Dictionary(uniqueKeysWithValues: folders.map { folder in
            (folder.name, Color(hex: folder.displayColor))
        })
    }

    private func runSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeApp = promptService.activeAppBundleID
        let folderColorByName = folderColorByNameCache

        if trimmedQuery.isEmpty {
            let entries = Array(
                indexedPrompts
                    .sorted(by: { lhs, rhs in
                        let lhsRecommended = activeApp != nil && lhs.prompt.targetAppBundleIDs.contains(activeApp!)
                        let rhsRecommended = activeApp != nil && rhs.prompt.targetAppBundleIDs.contains(activeApp!)

                        if lhsRecommended && !rhsRecommended { return true }
                        if !lhsRecommended && rhsRecommended { return false }

                        return lhs.prompt.createdAt > rhs.prompt.createdAt
                    })
                    .prefix(12)
            )

            filteredResults = entries.map { entry in
                makeSearchResultItem(entry: entry, activeApp: activeApp, folderColorByName: folderColorByName)
            }
        } else {
            let searchTerms = trimmedQuery
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            let scored = indexedPrompts.compactMap { entry -> (SearchIndexEntry, Int)? in
                var score = 0

                for term in searchTerms {
                    if entry.titleLower.contains(term) {
                        score += 500
                        if entry.titleLower.hasPrefix(term) { score += 100 }
                    }
                    if entry.descLower.contains(term) { score += 40 }
                    if entry.contentLower.contains(term) { score += 20 }
                    if entry.folderLower.contains(term) { score += 10 }
                }

                guard score > 0 else { return nil }

                if let activeApp, entry.prompt.targetAppBundleIDs.contains(activeApp) {
                    score += 1000
                }

                if entry.prompt.createdAt > Date().addingTimeInterval(-86400 * 7) {
                    score += 5
                }

                return (entry, score)
            }

            let entries = Array(
                scored
                    .sorted(by: { $0.1 > $1.1 })
                    .prefix(12)
            )

            filteredResults = entries.map { entry, _ in
                makeSearchResultItem(entry: entry, activeApp: activeApp, folderColorByName: folderColorByName)
            }
        }

        let currentValidIndices = Set(filteredResults.indices)
        visibleResultIndices = visibleResultIndices.intersection(currentValidIndices)

        if filteredResults.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= filteredResults.count {
            selectedIndex = max(0, filteredResults.count - 1)
        }
    }

    private func makeSearchResultItem(
        entry: SearchIndexEntry,
        activeApp: String?,
        folderColorByName: [String: Color]
    ) -> OmniSearchResultItem {
        let color: Color
        if let folderName = entry.payload.categoryName, let mapped = folderColorByName[folderName] {
            color = mapped
        } else if let folderName = entry.payload.categoryName {
            color = PredefinedCategory.fromString(folderName)?.color ?? .blue
        } else {
            color = .blue
        }

        let isRecommended = activeApp != nil && entry.prompt.targetAppBundleIDs.contains(activeApp!)

        return OmniSearchResultItem(
            id: entry.prompt.id,
            prompt: entry.prompt,
            title: entry.payload.title,
            subtitle: entry.payload.subtitle,
            iconName: entry.payload.iconName,
            categoryName: entry.payload.categoryName,
            hasVariables: entry.payload.hasVariables,
            hasNegative: entry.payload.hasNegative,
            hasAlternatives: entry.payload.hasAlternatives,
            categoryColor: color,
            isRecommended: isRecommended
        )
    }
    
    private func copyAndClose(_ prompt: Prompt) {
        ClipboardService.shared.copyToClipboard(prompt.content)
        HapticService.shared.playSuccess()
        if preferences.soundEnabled {
            SoundService.shared.playMagicSound()
        }
        manager.hide()
    }

    private func openEditorAndClose(_ prompt: Prompt) {
        let latestPrompt = promptService.promptSnapshot(byId: prompt.id) ?? prompt
        MenuBarManager.shared.promptToEditFromOmniSearch = latestPrompt
        MenuBarManager.shared.showWithState(.newPrompt)
        HapticService.shared.playLight()
        manager.hide()
    }
}

// MARK: - OmniSearchRow
struct OmniSearchRow: View {
    let item: OmniSearchResultItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onVisibilityChange: (Bool) -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icono del Prompt con color dinámico
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(item.categoryColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: item.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(item.categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Indicadores rápidos (Badges)
                        HStack(spacing: 5) {
                            if item.hasVariables {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.blue.opacity(0.8))
                                    .help("Has variables")
                            }
                            
                            if item.hasNegative {
                                Circle()
                                    .fill(Color.red.opacity(0.7))
                                    .frame(width: 5, height: 5)
                                    .help("Has negative prompt")
                            }
                            
                            if item.hasAlternatives {
                                Circle()
                                    .fill(Color.green.opacity(0.6))
                                    .frame(width: 5, height: 5)
                                    .help("Has alternatives")
                            }
                        }
                        
                        // Badge de Categoría
                        if let folder = item.categoryName, !folder.isEmpty {
                            Text(folder)
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(item.categoryColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.categoryColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        // Badge de Recomendación Inteligente (Contextual)
                        if item.isRecommended {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8, weight: .bold))
                                Text("recommended".localized(for: preferences.language))
                                    .font(.system(size: 11, weight: .black))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(item.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(item.categoryColor.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(item.categoryColor.opacity(0.25), lineWidth: 1.2)
                            )
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.primary.opacity(0.04))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onCopy()
        }
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            onVisibilityChange(true)
        }
        .onDisappear {
            onVisibilityChange(false)
        }
    }
}

// Extension para identificar la vista root en el NSPanel
extension NSView {
    var hostingView: NSHostingView<AnyView>? {
        return self as? NSHostingView<AnyView>
    }
}
