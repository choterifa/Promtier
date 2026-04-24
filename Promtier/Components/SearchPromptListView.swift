import SwiftUI

struct SearchPromptListView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @Binding var selectedPrompt: Prompt?
    @Binding var showingPreview: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var isUserNavigating: Bool
    
    var isPerformanceCardMode: Bool
    var categoryColor: (Prompt) -> Color
    var resolvedIcon: (Prompt) -> String
    
    // Actions
    var onSelect: (Prompt) -> Void
    var onDoubleTap: (Prompt) -> Void
    var onUse: (Prompt) -> Void
    var onCopyPack: (Prompt) -> Void
    var onHover: (Prompt, Bool) -> Void
    var contextMenu: (Prompt) -> AnyView
    var previewPopover: (Prompt, AnyView) -> AnyView
    
    var body: some View {
        if promptService.filteredPrompts.isEmpty {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "text.bubble")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.6))

                VStack(spacing: 12) {
                    Text(promptService.searchQuery.isEmpty ? "no_prompts".localized(for: preferences.language) : "no_results".localized(for: preferences.language))
                        .font(.system(size: 20 * preferences.fontSize.scale, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(promptService.searchQuery.isEmpty ? "create_first_prompt".localized(for: preferences.language) : "try_other_terms".localized(for: preferences.language))
                        .font(.system(size: 14 * preferences.fontSize.scale))
                        .foregroundColor(.secondary)
                }

                if promptService.searchQuery.isEmpty {
                    Button("create_first_prompt".localized(for: preferences.language)) {
                        // Handled by parent or app state
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 14)
            .padding(.trailing, 24)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    if preferences.isGridView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16) {
                            ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                previewPopover(prompt, AnyView(
                                    PromptGridCard(
                                        prompt: prompt,
                                        precomputedCategoryColor: categoryColor(prompt),
                                        isPerformanceMode: isPerformanceCardMode,
                                        isSelected: selectedPrompt?.id == prompt.id,
                                        isHovered: false,
                                        onTap: { onSelect(prompt) },
                                        onDoubleTap: { onDoubleTap(prompt) },
                                        onCopy: { onUse(prompt) },
                                        onHover: { isHovering in onHover(prompt, isHovering) }
                                    )
                                    .contextMenu { contextMenu(prompt) }
                                ))
                                .id(prompt.id)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .padding(.vertical, 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                previewPopover(prompt, AnyView(
                                    PromptCard(
                                        prompt: prompt,
                                        precomputedCategoryColor: categoryColor(prompt),
                                        precomputedResolvedIcon: resolvedIcon(prompt),
                                        isPerformanceMode: isPerformanceCardMode,
                                        isSelected: selectedPrompt?.id == prompt.id,
                                        isHovered: false,
                                        onTap: { onSelect(prompt) },
                                        onDoubleTap: { onDoubleTap(prompt) },
                                        onCopy: { onUse(prompt) },
                                        onCopyPack: { onCopyPack(prompt) },
                                        onHover: { isHovering in onHover(prompt, isHovering) }
                                    )
                                    .contextMenu { contextMenu(prompt) }
                                ))
                                .id(prompt.id)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .padding(.vertical, 16)
                    }
                }
                .scrollIndicators(.hidden)
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused.wrappedValue = false
                }
                .onChange(of: selectedPrompt?.id) { _, newId in
                    guard let id = newId, isUserNavigating else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}
