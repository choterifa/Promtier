import SwiftUI
import Foundation

struct PromptAdvancedFieldsView: View {
    @Binding var negativePrompt: String
    @Binding var alternatives: [String]
    @Binding var alternativeDescriptions: [String]
    @Binding var content: String
    @Binding var branchMessage: String?

    @Binding var focusNegative: Bool
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
    @Binding var activeGeneratingID: String?
    @Binding var selectedNegativeRange: NSRange?
    @Binding var aiNegativeResult: AIResult?
    @Binding var showingPremiumFor: String?
    @Binding var isGeneratingAlternativeDirect: Bool

    let themeColor: Color
    let currentCategoryColor: Color
    let preferences: PreferencesManager
    let isAIAvailable: Bool
    let canGenerateAlternative: Bool
    let originalPrompt: Prompt?
    let prompt: Prompt?

    let onZenNegative: () -> Void
    let onCompareNegative: () -> Void
    let onGenerateAlternativeDirect: () -> Void
    let onAlternativeRow: (Int) -> AnyView

    @State private var isHoveringAddAlternative = false
    @State private var isHoveringMagicVariant = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 24) {
                SecondaryEditorCard(
                    title: "negative_prompt".localized(for: preferences.language),
                    placeholder: "negative_prompt_placeholder".localized(for: preferences.language),
                    text: $negativePrompt,
                    icon: "hand.raised.fill",
                    color: .red,
                    focusRequest: $focusNegative,
                    onZenMode: onZenNegative,
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
                    isAIGenerating: Binding(
                        get: { activeGeneratingID == "negative" },
                        set: { val in activeGeneratingID = val ? "negative" : nil }
                    ),
                    selectedRange: $selectedNegativeRange,
                    aiResult: $aiNegativeResult,
                    showingPremiumFor: $showingPremiumFor,
                    originalPrompt: originalPrompt,
                    prompt: prompt,
                    branchMessage: $branchMessage,
                    editorID: "negative",
                    currentCategoryColor: currentCategoryColor
                ) {
                    HStack(spacing: 12) {
                        if !negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                withAnimation {
                                    let temp = content
                                    content = negativePrompt
                                    negativePrompt = temp
                                    branchMessage = "Content swapped!"
                                }
                                HapticService.shared.playLight()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation { branchMessage = nil }
                                }
                            }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            .help("Swap with main prompt")

                            Button(action: {
                                withAnimation {
                                    if !content.isEmpty { content += "\n\n---\n\n" }
                                    content += negativePrompt
                                    negativePrompt = ""
                                    branchMessage = "Merged into main!"
                                }
                                HapticService.shared.playLight()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation { branchMessage = nil }
                                }
                            }) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            .help("Merge into main prompt")

                            Button(action: onCompareNegative) {
                                Image(systemName: "arrow.left.and.right.text.vertical")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.orange)
                            .help("Compare with main prompt")
                        }
                    }
                }
                .id("negative_prompt_section")

                VStack(alignment: .leading, spacing: 16) {
                    if !alternatives.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(Array(alternatives.enumerated()), id: \.offset) { index, _ in
                                onAlternativeRow(index)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

                    if alternatives.count < 10 {
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    alternatives.append("")
                                    alternativeDescriptions.append("")
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("add_alternative".localized(for: preferences.language))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    ZStack {
                                        if preferences.isHaloEffectEnabled {
                                            currentCategoryColor.opacity((preferences.isPremiumActive && isAIAvailable) ? 0.05 : 0.15)
                                                .blur(radius: 12)
                                        }
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(themeColor.opacity(isHoveringAddAlternative ? 0.25 : 0.15))
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(themeColor.opacity(isHoveringAddAlternative ? 0.4 : 0.2), lineWidth: 1.5)
                                )
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isHoveringAddAlternative = hovering
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            if preferences.isPremiumActive && isAIAvailable {
                                Button(action: onGenerateAlternativeDirect) {
                                    HStack(spacing: 8) {
                                        if isGeneratingAlternativeDirect {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                        Text("magic_variant".localized(for: preferences.language))
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        ZStack {
                                            Color.blue.opacity(isHoveringMagicVariant ? 0.8 : 1.0)
                                            if preferences.isHaloEffectEnabled {
                                                Color.blue.opacity(isHoveringMagicVariant ? 0.5 : 0.3).blur(radius: 8)
                                            }
                                        }
                                    )
                                    .cornerRadius(14)
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isHoveringMagicVariant = hovering
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!canGenerateAlternative || isGeneratingAlternativeDirect)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .id("alternatives_section")
            }
        }
    }
}