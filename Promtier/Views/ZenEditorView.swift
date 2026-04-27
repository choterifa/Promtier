//
//  ZenEditorView.swift
//  Promtier
//
//  VISTA: Editor minimalista a pantalla completa
//

import SwiftUI

struct ZenEditorView: View {
    @Binding var title: String
    @Binding var content: String
    var isTitleEditable: Bool = true
    let onDone: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @FocusState private var isEditorFocused: Bool
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
    @Binding var selectedRange: NSRange?
    @Binding var aiResult: AIResult?
    @Binding var showingPremiumFor: String?
    var originalPrompt: Prompt?
    @Binding var branchMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header minimalista
            HStack(alignment: .top) {
                if isTitleEditable {
                    TextField("zen_title_placeholder".localized(for: preferences.language), text: $title, axis: .vertical)
                        .font(.system(size: 24 * preferences.fontSize.scale, weight: .bold))
                        .textFieldStyle(.plain)
                        .lineLimit(2)
                } else {
                    Text(title)
                        .font(.system(size: 24 * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: { 
                    if preferences.isPremiumActive {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showVariables.toggle()
                            variablesSelectedIndex = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isEditorFocused = true
                        }
                    } else {
                        showingPremiumFor = "advanced_variables".localized(for: preferences.language)
                    }
                }) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                Button(action: onDone) {
                    HStack {
                        Text("Exit")
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(32)
            
            // Editor Principal
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("zen_content_placeholder".localized(for: preferences.language))
                        .font(.system(size: 18 * preferences.fontSize.scale))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                HighlightedEditor(
                    text: $content,
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    triggerAIRequest: $triggerAIRequest,
                    isAIActive: $isAIActive,
                    editorID: "zen",
                    isFocused: Binding(
                        get: { isEditorFocused },
                        set: { isEditorFocused = $0 }
                    ),
                    selectedRange: $selectedRange,
                    aiResult: $aiResult,
                    fontSize: 18 * preferences.fontSize.scale,
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    showVariables: $showVariables,
                    variablesSelectedIndex: $variablesSelectedIndex,
                    triggerVariablesSelection: $triggerVariablesSelection,
                    isPremium: preferences.isPremiumActive,
                    isTyping: .constant(false)
                )
                .focused($isEditorFocused)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            
            // Footer con info
            HStack {
                HStack(spacing: 16) {
                    Label(String(format: "characters".localized(for: preferences.language), content.count), systemImage: "character.cursor.ibeam")
                    Label(String(format: "words_count".localized(for: preferences.language), content.split(separator: " ").count), systemImage: "text.word.spacing")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("auto_save_active".localized(for: preferences.language))
                    .font(.system(size: 12))
                    .foregroundColor(.green.opacity(0.8))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.primary.opacity(0.02))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isEditorFocused = true
        }
    }
}
