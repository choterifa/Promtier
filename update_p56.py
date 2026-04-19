import re

# To move setupKeyboardMonitor to ViewModel is complex because it binds to view state heavily.
# For step 6, let's create a new file: /Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptCoreFieldsView.swift
import os
os.makedirs("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views", exist_ok=True)

with open("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptCoreFieldsView.swift", "w") as f:
    f.write("""//
//  PromptCoreFieldsView.swift
//  Promtier
//

import SwiftUI

struct PromptCoreFieldsView: View {
    @Binding var title: String
    @Binding var promptDescription: String
    @Binding var content: String
    @Binding var isFavorite: Bool
    
    let currentCategoryColor: Color
    let preferences: PreferencesManager
    
    // Binding for the EditorCard arguments
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    @Binding var showVariables: Bool
    @Binding var variablesSelectedIndex: Int
    @Binding var triggerVariablesSelection: Bool
    @Binding var triggerAIRequest: String?
    @Binding var isAIActive: Bool
    @Binding var isAIGenerating: Bool
    
    let isAutocompleting: Bool
    let isCategorizing: Bool
    let onMagicAutocomplete: () -> Void
    let onMagicCategorize: () -> Void
    
    @Binding var selectedRange: NSRange?
    @Binding var aiResult: AIResult?
    let originalPrompt: Prompt?
    let prompt: Prompt?
    @Binding var branchMessage: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Título y Estrella
            HStack(alignment: .center) {
                TextField("title_placeholder".localized(for: preferences.language), text: $title)
                    .font(.system(size: 26 * preferences.fontSize.scale, weight: .black))
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary.opacity(0.9))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isFavorite.toggle()
                    }
                    HapticService.shared.playLight()
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isFavorite ? .yellow : .secondary.opacity(0.3))
                        .scaleEffect(isFavorite ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "remove_favorite".localized(for: preferences.language) : "add_favorite".localized(for: preferences.language))
            }
            .padding(.horizontal, 4)
            
            // Descripción (Opcional visualmente)
            TextField("description_optional_placeholder".localized(for: preferences.language), text: $promptDescription)
                .font(.system(size: 14 * preferences.fontSize.scale, weight: .medium))
                .textFieldStyle(.plain)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 4)
            
            // EDITOR PRINCIPAL
            EditorCard(
                title: "content".localized(for: preferences.language),
                placeholder: "content_placeholder".localized(for: preferences.language),
                text: $content,
                icon: "text.alignleft",
                color: currentCategoryColor,
                insertionRequest: $insertionRequest,
                replaceSnippetRequest: $replaceSnippetRequest,
                showSnippets: $showSnippets,
                snippetSearchQuery: $snippetSearchQuery,
                snippetSelectedIndex: $snippetSelectedIndex,
                triggerSnippetSelection: $triggerSnippetSelection,
                showVariables: $showVariables,
                variablesSelectedIndex: $variablesSelectedIndex,
                triggerVariablesSelection: $triggerVariablesSelection,
                triggerAIRequest: $triggerAIRequest,
                isAIActive: $isAIActive,
                isAIGenerating: $isAIGenerating,
                isAutocompleting: isAutocompleting,
                isCategorizing: isCategorizing,
                onMagicAutocomplete: onMagicAutocomplete,
                onMagicCategorize: onMagicCategorize,
                selectedRange: $selectedRange,
                aiResult: $aiResult,
                originalPrompt: originalPrompt,
                prompt: prompt,
                branchMessage: $branchMessage,
                editorID: "main",
                currentCategoryColor: currentCategoryColor
            )
        }
    }
}
""")
