import SwiftUI

struct NewPromptOverlaysManager: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    // Bindings
    @Binding var zenTarget: NewPromptView.ZenEditorTarget?
    @Binding var showingZenEditor: Bool
    var zenBindingTitle: Binding<String>
    var zenBindingContent: Binding<String>
    var zenBindingSelection: Binding<NSRange?>
    var zenBindingAIResult: Binding<AIResult?>
    @Binding var activeGeneratingID: String?
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
    @Binding var showingPremiumFor: String?
    var originalPrompt: Prompt?
    @Binding var branchMessage: String?
    
    @Binding var showParticles: Bool
    var currentCategoryColor: Color
    
    @Binding var showingMagicOptions: Bool
    @Binding var magicTarget: MagicTarget
    @Binding var magicCommand: String
    var executeMagicWithCommand: () -> Void

    var body: some View {
        Group {
            if let target = zenTarget {
                ZenEditorView(
                    title: zenBindingTitle,
                    content: zenBindingContent,
                    isTitleEditable: { if case .main = target { return true } else { return false } }(),
                    onDone: { withAnimation(.spring()) { zenTarget = nil; showingZenEditor = false } },
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
                        get: {
                            let targetIndex = {
                                if case .alternative(let i) = target { return i }
                                return 0
                            }()
                            return activeGeneratingID == (target == .main ? "main" : (target == .negative ? "negative" : "alt-\(targetIndex)"))
                        },
                        set: { val in
                            if !val { activeGeneratingID = nil }
                        }
                    ),
                    selectedRange: zenBindingSelection,
                    aiResult: zenBindingAIResult,
                    showingPremiumFor: $showingPremiumFor,
                    originalPrompt: originalPrompt,
                    branchMessage: $branchMessage
                )
                .environmentObject(preferences)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(150)
            }
            
            snippetsOverlayLayer
            variablesOverlayLayer
            
            if showParticles {
                ParticleSystemView(accentColor: currentCategoryColor)
                    .allowsHitTesting(false)
                    .zIndex(300)
            }
            
            NewPromptMagicOptionsOverlay(
                showingMagicOptions: $showingMagicOptions,
                magicTarget: $magicTarget,
                magicCommand: $magicCommand,
                executeAction: executeMagicWithCommand
            )

            if let msg = branchMessage {
                NewPromptBranchMessageOverlay(
                    message: msg,
                    language: preferences.language
                )
            }
        }
    }

    private var snippetsOverlayLayer: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showSnippets = false } }
            snippetOverlay
                .scaleEffect(showSnippets ? 1.0 : 0.98, anchor: .bottom)
                .offset(y: showSnippets ? 0 : 10)
                .opacity(showSnippets ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(showSnippets ? 1.0 : 0.0)
        .allowsHitTesting(showSnippets)
        .animation(.easeOut(duration: 0.15), value: showSnippets)
        .zIndex(200)
    }

    private var variablesOverlayLayer: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showVariables = false } }
            variablesOverlay
                .scaleEffect(showVariables ? 1.0 : 0.98, anchor: .bottom)
                .offset(y: showVariables ? 0 : 10)
                .opacity(showVariables ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(showVariables ? 1.0 : 0.0)
        .allowsHitTesting(showVariables)
        .animation(.easeOut(duration: 0.15), value: showVariables)
        .zIndex(201)
    }

    private var snippetOverlay: some View {
        VStack {
            Spacer()
            if !preferences.isPremiumActive {
                PremiumUpsellView(
                    featureName: "quick_snippets".localized(for: preferences.language),
                    onCancel: {
                        withAnimation { showSnippets = false }
                    }
                )
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                .padding(.bottom, 24)
            } else {
                SnippetsPopupList(
                    query: snippetSearchQuery,
                    selectedIndex: $snippetSelectedIndex,
                    triggerSelection: $triggerSnippetSelection,
                    onSelect: { snippet in
                        replaceSnippetRequest = snippet.content
                    },
                    onDismiss: {
                        withAnimation { showSnippets = false }
                    }
                )
                .padding(.bottom, 24)
            }
        }
    }

    private var variablesOverlay: some View {
        VStack {
            Spacer()
            if !preferences.isPremiumActive {
                PremiumUpsellView(
                    featureName: "dynamic_variables".localized(for: preferences.language),
                    onCancel: {
                        withAnimation { showVariables = false }
                    }
                )
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                .padding(.bottom, 24)
            } else {
                VariablesPopupList(
                    selectedIndex: $variablesSelectedIndex,
                    triggerSelection: $triggerVariablesSelection,
                    onSelect: { option in
                        insertionRequest = option.insertionText
                        withAnimation { showVariables = false }
                    },
                    onDismiss: {
                        withAnimation { showVariables = false }
                    }
                )
                .padding(.bottom, 24)
            }
        }
    }
}
