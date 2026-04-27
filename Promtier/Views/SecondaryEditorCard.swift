import SwiftUI
import AppKit

struct SecondaryEditorCard<Actions: View>: View {
    let title: String
    let subtitle: String?
    var subtitleBinding: Binding<String>? = nil
    var subtitlePlaceholder: String? = nil
    let placeholder: String
    @Binding var text: String
    let icon: String
    let color: Color

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? color : .blue
    }
    var focusRequest: Binding<Bool>? = nil
    var onZenMode: (() -> Void)? = nil

    // Bindings for standard actions
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
    var prompt: Prompt?
    @Binding var branchMessage: String?
    let editorID: String
    let currentCategoryColor: Color

    let actions: Actions
    private let hasCustomActions: Bool

    var isAutocompleting: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil

    @EnvironmentObject var preferences: PreferencesManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String, subtitle: String? = nil, subtitleBinding: Binding<String>? = nil, subtitlePlaceholder: String? = nil, placeholder: String, text: Binding<String>, icon: String, color: Color,
         focusRequest: Binding<Bool>? = nil, onZenMode: (() -> Void)? = nil,
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>,
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>,
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>,
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>,
         triggerVariablesSelection: Binding<Bool>, triggerAIRequest: Binding<String?>,
         isAIActive: Binding<Bool>, isAIGenerating: Binding<Bool>,
         isAutocompleting: Bool = false, onMagicAutocomplete: (() -> Void)? = nil,
         selectedRange: Binding<NSRange?>, aiResult: Binding<AIResult?>,
         showingPremiumFor: Binding<String?>, originalPrompt: Prompt? = nil,
         prompt: Prompt? = nil, branchMessage: Binding<String?>,
         editorID: String, currentCategoryColor: Color,
         @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleBinding = subtitleBinding
        self.subtitlePlaceholder = subtitlePlaceholder
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.color = color
        self.focusRequest = focusRequest
        self.onZenMode = onZenMode
        self._insertionRequest = insertionRequest
        self._replaceSnippetRequest = replaceSnippetRequest
        self._showSnippets = showSnippets
        self._snippetSearchQuery = snippetSearchQuery
        self._snippetSelectedIndex = snippetSelectedIndex
        self._triggerSnippetSelection = triggerSnippetSelection
        self._showVariables = showVariables
        self._variablesSelectedIndex = variablesSelectedIndex
        self._triggerVariablesSelection = triggerVariablesSelection
        self._triggerAIRequest = triggerAIRequest
        self._isAIActive = isAIActive
        self._isAIGenerating = isAIGenerating
        self._selectedRange = selectedRange
        self._aiResult = aiResult
        self._showingPremiumFor = showingPremiumFor
        self.isAutocompleting = isAutocompleting
        self.onMagicAutocomplete = onMagicAutocomplete
        self.originalPrompt = originalPrompt
        self.prompt = prompt
        self._branchMessage = branchMessage
        self.editorID = editorID
        self.currentCategoryColor = currentCategoryColor
        self.actions = actions()
        self.hasCustomActions = Actions.self != EmptyView.self
    }

    private var isAIAvailable: Bool {
        EditorAIUtilities.isAIAvailable(for: preferences)
    }

    private var cardFocusAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.3)
    }

    private var cardHoverAnimation: Animation? {
        if reduceMotion || isTyping { return nil }
        return .easeInOut(duration: 0.2)
    }

    private var cardTypingAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isTyping
            ? .spring(response: 0.35, dampingFraction: 0.7)
            : .easeOut(duration: 1.5)
    }

    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var plainTextContent: String = ""
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var showingInstructionAlert = false
    @State private var instructionInput = ""

    // MARK: - SecondaryEditorCard Body

    var body: some View {
        let iconColor: Color = (icon == "hand.raised.fill") ? Color.red.opacity(0.8) : themeColor

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)

                if hasCustomActions {
                    actions
                        .padding(.leading, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            if let subtitleBinding {
                TextField(
                    subtitlePlaceholder ?? "",
                    text: Binding(
                        get: { subtitleBinding.wrappedValue },
                        set: { subtitleBinding.wrappedValue = String($0.replacingOccurrences(of: "\n", with: " ").prefix(120)) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
            } else if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
            }

            // Editor secundario con herramientas inteligentes (sidebar layout)
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HighlightedEditor(
                        text: $text,
                        plainText: $plainTextContent,
                        insertionRequest: $insertionRequest,
                        replaceSnippetRequest: $replaceSnippetRequest,
                        triggerAIRequest: $triggerAIRequest,
                        isAIActive: $isAIActive,
                        editorID: editorID,
                        isFocused: $isEditorFocused,
                        focusRequest: focusRequest,
                        selectedRange: $selectedRange,
                        aiResult: $aiResult,
                        fontSize: 14 * preferences.fontSize.scale,
                        themeColor: NSColor(color),
                        showSnippets: $showSnippets,
                        snippetSearchQuery: $snippetSearchQuery,
                        snippetSelectedIndex: $snippetSelectedIndex,
                        triggerSnippetSelection: $triggerSnippetSelection,
                        showVariables: $showVariables,
                        variablesSelectedIndex: $variablesSelectedIndex,
                        triggerVariablesSelection: $triggerVariablesSelection,
                        isPremium: preferences.isPremiumActive,
                        isHaloEffectEnabled: preferences.isHaloEffectEnabled,
                        isTyping: $isTyping
                    )
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 5)
                    .frame(maxWidth: .infinity, minHeight: 180)

                    if plainTextContent.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14 * preferences.fontSize.scale))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.leading, 22)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

                EditorToolbar(
                    color: color,
                    editorID: editorID,
                    vertical: true,
                    content: $text,
                    selectedRange: $selectedRange,
                    isAIGenerating: isAIGenerating,
                    onAIAction: { performAIAction($0) },
                    aiEnabled: isAIAvailable,
                    onShowVariables: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showVariables.toggle()
                                variablesSelectedIndex = 0
                            }
                        } else {
                            showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                        }
                    },
                    onShowSnippets: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSnippets.toggle()
                                snippetSearchQuery = ""
                            }
                        } else {
                            showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                        }
                    },
                    showingPromptChainPicker: $showingPromptChainPicker,
                    chainPopoverContent: {
                        AnyView(
                            PromptPickerPopover(excludePromptId: prompt?.id) { selected in
                                insertionRequest = "[[@Prompt:\(selected.title)]]"
                                showingPromptChainPicker = false
                            }
                        )
                    },
                    onZenMode: {
                        onZenMode?()
                    },
                    onFloatingMode: nil,
                    isAutocompleting: isAIGenerating,
                    onMagicAutocomplete: isAIAvailable
                        ? {
                            if let onMagicAutocomplete {
                                onMagicAutocomplete()
                            } else {
                                performAIAction(.enhance)
                            }
                        }
                        : nil
                )
                .scaleEffect(0.9)
                .padding(.vertical, 8)
                .padding(.trailing, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                            .stroke(
                                themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)),
                                lineWidth: isTyping ? Theme.Layout.EditorCard.activeBorderWidth : Theme.Layout.EditorCard.idleBorderWidth
                            )
                            .shadow(color: preferences.isHaloEffectEnabled ? themeColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .animation(cardFocusAnimation, value: isEditorFocused)
            .animation(cardHoverAnimation, value: isHovering)
            .animation(cardTypingAnimation, value: isTyping)
            .contentShape(Rectangle())
            .onHover { hovering in
                guard isHovering != hovering else { return }
                isHovering = hovering
            }
        }
        .alert("Execute Command", isPresented: $showingInstructionAlert) {
            TextField("Instruction (e.g. Translate to French)", text: $instructionInput)
            Button("Cancel", role: .cancel) { }
            Button("Execute") {
                performAIAction(.instruct, instruction: instructionInput)
            }
        } message: {
            Text("Enter the instruction to apply to the selected text.")
        }
    }

    // MARK: - SecondaryEditorCard AI

    private func performAIAction(_ action: AIAction, instruction: String? = nil) {
        guard isAIAvailable else { return }

        if action == .instruct && instruction == nil {
            instructionInput = ""
            showingInstructionAlert = true
            return
        }

        EditorAIUtilities.beginActionUI(
            language: preferences.language,
            setIsAIGenerating: { self.isAIGenerating = $0 },
            setBranchMessage: { self.branchMessage = $0 }
        )

        aiTask?.cancel()
        aiTask = Task {
            let executionResult = await EditorAIUtilities.executeAction(
                action: action,
                instruction: instruction,
                primaryText: text,
                plainText: plainTextContent,
                selectedRange: selectedRange,
                language: preferences.language
            )

            await MainActor.run {
                self.isAIGenerating = false

                switch executionResult {
                case .noProcessableText:
                    return
                case let .success(result, _):
                    EditorAIUtilities.applySuccessUI(
                        result: result,
                        setBranchMessage: { self.branchMessage = $0 },
                        setAIResult: { self.aiResult = $0 }
                    )
                case let .failure(toastMessage, _):
                    EditorAIUtilities.applyFailureUI(
                        toastMessage: toastMessage,
                        setBranchMessage: { self.branchMessage = $0 },
                        getCurrentBranchMessage: { self.branchMessage }
                    )
                }
            }
        }
    }
}
