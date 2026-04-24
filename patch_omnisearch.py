import re

with open('Promtier/Views/OmniSearchView.swift', 'r') as f:
    content = f.read()

# 1. Remove SearchItemPayload and SearchIndexEntry
content = re.sub(
    r'struct OmniSearchView: View \{\s+private struct SearchItemPayload \{.*?\}\s+private struct SearchIndexEntry \{.*?\}\s+@EnvironmentObject',
    r'struct OmniSearchView: View {\n    @EnvironmentObject',
    content,
    flags=re.DOTALL
)

# 2. Remove indexedPrompts state
content = re.sub(
    r'@State private var indexedPrompts: \[SearchIndexEntry\] = \[\]\n',
    r'',
    content
)

# 3. Fix onAppear
content = re.sub(
    r'\.onAppear \{\s+rebuildFolderColorCache\(from: promptService\.folders\)\s+rebuildSearchIndex\(from: promptService\.prompts\)\s+runSearch\(\)',
    r'.onAppear {\n            rebuildFolderColorCache(from: promptService.folders)\n            runSearch()',
    content
)

# 4. Fix onReceive for prompts
content = re.sub(
    r'\.onReceive\(promptService\.\$prompts\) \{ prompts in\s+rebuildSearchIndex\(from: prompts\)\s+runSearch\(\)\s+\}',
    r'.onReceive(promptService.$prompts) { _ in\n            runSearch()\n        }',
    content
)

# 5. Replace rebuildSearchIndex, runSearch, makeSearchResultItem
new_methods = """
    private func rebuildFolderColorCache(from folders: [Folder]) {
        folderColorByNameCache = Dictionary(uniqueKeysWithValues: folders.map { folder in
            (folder.name, Color(hex: folder.displayColor))
        })
    }

    private func runSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeApp = promptService.activeAppBundleID
        let folderColorByName = folderColorByNameCache

        promptService.searchEngine.filterPrompts(
            prompts: promptService.prompts,
            folders: promptService.folders,
            query: trimmedQuery,
            categoryOverride: "all", // Buscar en todas las categorías
            selectedCategory: nil,
            activeAppBundleID: activeApp,
            promptSortMode: trimmedQuery.isEmpty ? .mostUsed : promptService.promptSortMode
        ) { [weak self] results in
            guard let self = self else { return }
            
            let topResults = Array(results.prefix(12))
            
            let newFilteredResults = topResults.map { prompt in
                self.makeSearchResultItem(prompt: prompt, activeApp: activeApp, folderColorByName: folderColorByName)
            }
            
            self.filteredResults = newFilteredResults
            
            let currentValidIndices = Set(self.filteredResults.indices)
            self.visibleResultIndices = self.visibleResultIndices.intersection(currentValidIndices)

            if self.filteredResults.isEmpty {
                self.selectedIndex = 0
            } else if self.selectedIndex >= self.filteredResults.count {
                self.selectedIndex = max(0, self.filteredResults.count - 1)
            }
        }
    }

    private func makeSearchResultItem(
        prompt: Prompt,
        activeApp: String?,
        folderColorByName: [String: Color]
    ) -> OmniSearchResultItem {
        let color: Color
        if let folderName = prompt.folder, let mapped = folderColorByName[folderName] {
            color = mapped
        } else if let folderName = prompt.folder {
            color = PredefinedCategory.fromString(folderName)?.color ?? .blue
        } else {
            color = .blue
        }

        let isRecommended = activeApp != nil && prompt.targetAppBundleIDs.contains(activeApp!)
        
        let subtitle: String
        if let desc = prompt.promptDescription, !desc.isEmpty {
            subtitle = desc
        } else {
            subtitle = prompt.content
        }

        return OmniSearchResultItem(
            id: prompt.id,
            prompt: prompt,
            title: prompt.title,
            subtitle: subtitle,
            iconName: prompt.icon ?? "doc.text.fill",
            categoryName: prompt.folder,
            hasVariables: prompt.hasTemplateVariables(),
            hasNegative: !(prompt.negativePrompt?.isEmpty ?? true),
            hasAlternatives: !prompt.alternatives.isEmpty || !(prompt.alternativePrompt?.isEmpty ?? true),
            categoryColor: color,
            isRecommended: isRecommended
        )
    }
"""

content = re.sub(
    r'private func rebuildSearchIndex\(from prompts: \[Prompt\]\).*?isRecommended: isRecommended\n        \)\n    \}',
    new_methods.strip(),
    content,
    flags=re.DOTALL
)

with open('Promtier/Views/OmniSearchView.swift', 'w') as f:
    f.write(content)

