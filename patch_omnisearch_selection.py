import re

with open('Promtier/Views/OmniSearchView.swift', 'r') as f:
    content = f.read()

# 1. Replace @State private var selectedIndex: Int = 0 with selectedPromptId
content = re.sub(
    r'@State private var selectedIndex: Int = 0',
    r'@State private var selectedPromptId: UUID?',
    content
)

# 2. In onChange(of: query)
content = re.sub(
    r'selectedIndex = 0\s+scheduleSearch\(\)',
    r'scheduleSearch()',
    content
)

# 3. In onSubmit
content = re.sub(
    r'\.onSubmit \{\s+if !filteredResults\.isEmpty \{\s+copyAndClose\(filteredResults\[selectedIndex\]\.prompt\)\s+\}\s+\}',
    r'.onSubmit {\n                        if let id = selectedPromptId, let item = filteredResults.first(where: { $0.id == id }) {\n                            copyAndClose(item.prompt)\n                        } else if let first = filteredResults.first {\n                            copyAndClose(first.prompt)\n                        }\n                    }',
    content
)

# 4. In runSearch completion
old_runsearch_end = """
            filteredResults = newFilteredResults
            
            let currentValidIndices = Set(filteredResults.indices)
            visibleResultIndices = visibleResultIndices.intersection(currentValidIndices)

            if filteredResults.isEmpty {
                selectedIndex = 0
            } else if selectedIndex >= filteredResults.count {
                selectedIndex = max(0, filteredResults.count - 1)
            }
        }
"""
new_runsearch_end = """
            filteredResults = newFilteredResults
            
            if !filteredResults.isEmpty {
                if selectedPromptId == nil || !filteredResults.contains(where: { $0.id == selectedPromptId }) {
                    selectedPromptId = filteredResults.first?.id
                }
            } else {
                selectedPromptId = nil
            }
        }
"""
content = content.replace(old_runsearch_end, new_runsearch_end)

# 5. In CommandEvent processing
old_commands = """
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
"""

new_commands = """
            case .opened:
                query = ""
                runSearch()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }

            case .moveDown:
                guard !filteredResults.isEmpty else { return }
                if let currentId = selectedPromptId, let idx = filteredResults.firstIndex(where: { $0.id == currentId }) {
                    if idx < filteredResults.count - 1 {
                        selectedPromptId = filteredResults[idx + 1].id
                        HapticService.shared.playLight()
                    }
                } else {
                    selectedPromptId = filteredResults.first?.id
                    HapticService.shared.playLight()
                }

            case .moveUp:
                guard !filteredResults.isEmpty else { return }
                if let currentId = selectedPromptId, let idx = filteredResults.firstIndex(where: { $0.id == currentId }) {
                    if idx > 0 {
                        selectedPromptId = filteredResults[idx - 1].id
                        HapticService.shared.playLight()
                    }
                } else {
                    selectedPromptId = filteredResults.first?.id
                    HapticService.shared.playLight()
                }

            case .submit, .copy:
                if let id = selectedPromptId, let item = filteredResults.first(where: { $0.id == id }) {
                    copyAndClose(item.prompt)
                } else if let first = filteredResults.first {
                    copyAndClose(first.prompt)
                }

            case .edit:
                if let id = selectedPromptId, let item = filteredResults.first(where: { $0.id == id }) {
                    openEditorAndClose(item.prompt)
                } else if let first = filteredResults.first {
                    openEditorAndClose(first.prompt)
                }
"""
content = content.replace(old_commands, new_commands)

# 6. In ForEach and List
old_list = """
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
"""

new_list = """
                        LazyVStack(spacing: 6) {
                            ForEach(filteredResults, id: \.id) { result in
                                OmniSearchRow(
                                    item: result,
                                    isSelected: selectedPromptId == result.id,
                                    onSelect: {
                                        selectedPromptId = result.id
                                        isFocused = false
                                    },
                                    onHover: { hovering in
                                        if hovering {
                                            selectedPromptId = result.id
                                        }
                                    },
                                    onCopy: {
                                        copyAndClose(result.prompt)
                                    }
                                )
                                .id(result.id)
                            }
                        }
                        .padding(12)
                    }
                    .background(Color.black.opacity(0.001))
                    .frame(maxHeight: 380)
                    .onChange(of: selectedPromptId) { _, newValue in
                        if let id = newValue {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
"""
content = content.replace(old_list, new_list)

# 7. Update OmniSearchRow declaration to accept onHover instead of onVisibilityChange
content = re.sub(
    r'let onSelect: \(\) -> Void\n    let onCopy: \(\) -> Void\n    let onVisibilityChange: \(Bool\) -> Void',
    r'let onSelect: () -> Void\n    let onHover: (Bool) -> Void\n    let onCopy: () -> Void',
    content
)

content = re.sub(
    r'\.onHover \{ hovering in\s+withAnimation\(\.easeInOut\(duration: 0\.15\)\) \{\s+isHovered = hovering\s+\}\s+\}\s+\.onAppear \{\s+onVisibilityChange\(true\)\s+\}\s+\.onDisappear \{\s+onVisibilityChange\(false\)\s+\}',
    r'.onHover { hovering in\n            withAnimation(.easeInOut(duration: 0.15)) {\n                isHovered = hovering\n            }\n            onHover(hovering)\n        }',
    content
)

# 8. Clean up visibleResultIndices which is not used anymore
content = re.sub(r'@State private var visibleResultIndices: Set<Int> = \[\]\n\s+', '', content)

with open('Promtier/Views/OmniSearchView.swift', 'w') as f:
    f.write(content)

