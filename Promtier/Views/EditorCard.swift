import SwiftUI
import AppKit


struct EditorCard: View {
    private enum Layout {
        static let headerSectionSpacing: CGFloat = 14
        static let headerRowSpacing: CGFloat = 14
        static let iconCornerRadius: CGFloat = 12
        static let iconFrameSize: CGFloat = 42
        static let iconSymbolSize: CGFloat = 18
        static let titleStackSpacing: CGFloat = 6
        static let titleFontSize: CGFloat = 22
        static let descriptionFontSize: CGFloat = 13
        static let descriptionMinHeight: CGFloat = 28
        static let editorFontSize: CGFloat = 16
        static let editorVerticalPadding: CGFloat = 8
        static let editorLeadingPadding: CGFloat = 8
        static let editorTrailingPadding: CGFloat = 5
        static let toolbarVerticalPadding: CGFloat = 8
        static let toolbarTrailingPadding: CGFloat = 4
        static let categoryHorizontalPadding: CGFloat = 8
        static let categoryTopPadding: CGFloat = 8
    }

    @Binding var title: String
    @Binding var content: String
    @Binding var promptDescription: String
    @Binding var isFavorite: Bool
    @Binding var selectedFolder: String?
    @Binding var selectedIcon: String?
    let fallbackIconName: String
    @Binding var showingIconPicker: Bool
    @Binding var showingZenEditor: Bool
    @Binding var zenTarget: NewPromptView.ZenEditorTarget?
    @Binding var showingPremiumFor: String?
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
    var originalPrompt: Prompt?
    var prompt: Prompt?
    @Binding var branchMessage: String?
    let editorID: String

    @ObservedObject var viewModel: NewPromptViewModel
    let currentCategoryColor: Color
    
    var isAutocompleting: Bool = false
    var isCategorizing: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil
    var onMagicCategorize: (() -> Void)? = nil

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : Color.blue
    }

    @EnvironmentObject var preferences: PreferencesManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(title: Binding<String>, content: Binding<String>, promptDescription: Binding<String>, 
         isFavorite: Binding<Bool>, selectedFolder: Binding<String?>, selectedIcon: Binding<String?>, 
         fallbackIconName: String, showingIconPicker: Binding<Bool>, showingZenEditor: Binding<Bool>, 
         zenTarget: Binding<NewPromptView.ZenEditorTarget?>, showingPremiumFor: Binding<String?>, 
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>, 
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>, 
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>, 
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>, 
         triggerVariablesSelection: Binding<Bool>, triggerAIRequest: Binding<String?>, 
         isAIActive: Binding<Bool>, isAIGenerating: Binding<Bool>, 
         isAutocompleting: Bool = false, isCategorizing: Bool = false, 
         onMagicAutocomplete: (() -> Void)? = nil, onMagicCategorize: (() -> Void)? = nil, 
         selectedRange: Binding<NSRange?>, aiResult: Binding<AIResult?>, 
         originalPrompt: Prompt? = nil, prompt: Prompt? = nil, 
         branchMessage: Binding<String?>, editorID: String, 
         viewModel: NewPromptViewModel,
         currentCategoryColor: Color) {
        self._title = title
        self._content = content
        self._promptDescription = promptDescription
        self._isFavorite = isFavorite
        self._selectedFolder = selectedFolder
        self._selectedIcon = selectedIcon
        self.fallbackIconName = fallbackIconName
        self._showingIconPicker = showingIconPicker
        self._showingZenEditor = showingZenEditor
        self._zenTarget = zenTarget
        self._showingPremiumFor = showingPremiumFor
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
        self.isAutocompleting = isAutocompleting
        self.isCategorizing = isCategorizing
        self.onMagicAutocomplete = onMagicAutocomplete
        self.onMagicCategorize = onMagicCategorize
        self._selectedRange = selectedRange
        self._aiResult = aiResult
        self.originalPrompt = originalPrompt
        self.prompt = prompt
        self._branchMessage = branchMessage
        self.editorID = editorID
        self.viewModel = viewModel
        self.currentCategoryColor = currentCategoryColor
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

    private var magicPulseAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return isMagicPulsing
            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
            : .spring(response: 0.3, dampingFraction: 0.7)
    }

    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var isMagicPulsing = false
    @State private var isMagicHovered = false
    @State private var magicRotationPhase: Double = 0
    @State private var plainTextContent: String = ""
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var showingInstructionAlert = false
    @State private var instructionInput = ""
    @State private var isDraggingMagicImage = false

    // MARK: - EditorCard Body

    var body: some View {
        VStack(spacing: 0) {
            promptHeaderSection
            primaryEditorSection
            categoryPickerSection

        } // Cierre del VStack principal body
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

    // MARK: - EditorCard Sections

    private var promptHeaderSection: some View {
        VStack(alignment: .leading, spacing: Layout.headerSectionSpacing) {
            HStack(alignment: .top, spacing: Layout.headerRowSpacing) {
                promptIconButton

                VStack(alignment: .leading, spacing: Layout.titleStackSpacing) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: Layout.titleFontSize * preferences.fontSize.scale, weight: .bold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // ✨ Botón Mágico: Autocompletar Título
                        if editorID == "main" {
                            MagicImageDropZone(isDraggingImage: $isDraggingMagicImage) { data in
                                extractMagicPrompt(from: data)
                            }
                            .scaleEffect(0.65)
                            .frame(width: 26, height: 26)
                            .padding(.trailing, 2)

                            Button(action: {
                                if reduceMotion {
                                    isMagicPulsing = false
                                } else {
                                    withAnimation { isMagicPulsing = false }
                                }
                                onMagicAutocomplete?()
                            }) {
                                HStack(spacing: 4) {
                                    if isAutocompleting {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.4)
                                            .frame(width: 8, height: 8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 10, weight: .bold))
                                            .frame(width: 12, height: 12)
                                    }

                                    Text(isAutocompleting ? "STOP" : "MAGIC")
                                        .font(.system(size: 10.5, weight: .heavy))
                                        .frame(width: 42, alignment: .center)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(preferences.isHaloEffectEnabled
                                            ? AnyShapeStyle(LinearGradient(
                                                colors: [currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22), currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            : AnyShapeStyle(themeColor.opacity(isMagicHovered ? 0.15 : 0.08)))
                                        .opacity(isMagicPulsing ? 0.5 : 1.0)
                                        .shadow(color: (preferences.isHaloEffectEnabled && isMagicPulsing) ? currentCategoryColor.opacity(0.7) : (preferences.isHaloEffectEnabled && isMagicHovered ? currentCategoryColor.opacity(0.6) : .clear),
                                               radius: isMagicPulsing ? 8 : (isMagicHovered ? 14 : 0))
                                )
                                .foregroundColor(isMagicHovered ? themeColor : themeColor.opacity(0.9))
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            preferences.isHaloEffectEnabled
                                                ? AnyShapeStyle(AngularGradient(
                                                    colors: [currentCategoryColor, currentCategoryColor.opacity(0.1), currentCategoryColor],
                                                    center: .center,
                                                    startAngle: .degrees(magicRotationPhase),
                                                    endAngle: .degrees(magicRotationPhase + 360)
                                                ))
                                                : AnyShapeStyle(themeColor.opacity(0.8)),
                                            lineWidth: isMagicPulsing ? 1.4 : (isMagicHovered ? 1.2 : 0.8)
                                        )
                                        .opacity(isMagicPulsing ? 0.8 : (isMagicHovered ? 1.0 : 0.5))
                                )
                                .scaleEffect(isMagicHovered ? 1.02 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                guard !reduceMotion else { return }
                                withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                                    magicRotationPhase = 360
                                }
                            }
                            .onHover { hovering in
                                guard isMagicHovered != hovering else { return }
                                if reduceMotion {
                                    isMagicHovered = hovering
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isMagicHovered = hovering
                                    }
                                }
                            }
                            .animation(magicPulseAnimation, value: isMagicPulsing)
                            .help("Autocomplete content based on title (Cmd+J)")
                            .padding(.top, 2)
                        }
                    }

                    TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: Layout.descriptionFontSize * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                        .frame(minHeight: Layout.descriptionMinHeight, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var primaryEditorSection: some View {
        HStack(alignment: .top, spacing: 0) {
            HighlightedEditor(
                text: $content,
                plainText: $plainTextContent,
                insertionRequest: $insertionRequest,
                replaceSnippetRequest: $replaceSnippetRequest,
                triggerAIRequest: $triggerAIRequest,
                isAIActive: $isAIActive,
                editorID: editorID,
                isFocused: $isEditorFocused,
                selectedRange: $selectedRange,
                aiResult: $aiResult,
                fontSize: Layout.editorFontSize * preferences.fontSize.scale,
                themeColor: NSColor(themeColor),
                showSnippets: $showSnippets,
                snippetSearchQuery: $snippetSearchQuery,
                snippetSelectedIndex: $snippetSelectedIndex,
                triggerSnippetSelection: $triggerSnippetSelection,
                showVariables: $showVariables,
                variablesSelectedIndex: $variablesSelectedIndex,
                triggerVariablesSelection: $triggerVariablesSelection,
                isPremium: preferences.isPremiumActive,
                isHaloEffectEnabled: preferences.isHaloEffectEnabled,
                isTyping: $isTyping,
                onPaste: {
                    if reduceMotion {
                        isMagicPulsing = true
                    } else {
                        withAnimation(.spring()) {
                            isMagicPulsing = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                        if reduceMotion {
                            isMagicPulsing = false
                        } else {
                            withAnimation(.easeInOut) {
                                isMagicPulsing = false
                            }
                        }
                    }
                }
            )
            .padding(.vertical, Layout.editorVerticalPadding)
            .padding(.leading, Layout.editorLeadingPadding)
            .padding(.trailing, Layout.editorTrailingPadding)
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)

            EditorToolbar(
                color: currentCategoryColor,
                editorID: editorID,
                vertical: true,
                content: $content,
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingZenEditor = true
                        zenTarget = .main
                    }
                },
                onFloatingMode: nil,
                isAutocompleting: isAutocompleting,
                onMagicAutocomplete: editorID == "main" ? nil : { onMagicAutocomplete?() },
                onStopAI: {
                    aiTask?.cancel()
                    isAIGenerating = false
                }
            )
            .padding(.vertical, Layout.toolbarVerticalPadding)
            .padding(.trailing, Layout.toolbarTrailingPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Layout.EditorCard.cornerRadius)
                        .stroke(themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isTyping ? Theme.Layout.EditorCard.activeBorderWidth : Theme.Layout.EditorCard.idleBorderWidth)
                        .shadow(color: preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                )
        )
        .padding(.top, Theme.Layout.EditorCard.sectionTopPadding)
        .animation(cardFocusAnimation, value: isEditorFocused)
        .animation(cardHoverAnimation, value: isHovering)
        .animation(cardTypingAnimation, value: isTyping)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard isHovering != hovering else { return }
            isHovering = hovering
        }
    }

    private var promptIconButton: some View {
        Button(action: { showingIconPicker.toggle() }) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.iconCornerRadius)
                    .fill(themeColor.opacity(0.1))
                    .frame(width: Layout.iconFrameSize, height: Layout.iconFrameSize)

                Image(systemName: selectedIcon ?? fallbackIconName)
                    .font(.system(size: Layout.iconSymbolSize, weight: .semibold))
                    .foregroundColor(themeColor)
            }
        }
        .buttonStyle(.plain)
        .help("Change icon")
        .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
            IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
        }
    }

    private var categoryPickerSection: some View {
        HStack(spacing: 8) {
            CategoryPillPicker(selectedCategory: $selectedFolder, isFavorite: $isFavorite, showLabel: false)
        }
        .padding(.horizontal, Layout.categoryHorizontalPadding)
        .padding(.top, Layout.categoryTopPadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - EditorCard AI

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
                primaryText: content,
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

    // MARK: - EditorCard Magic Image

    private func extractMagicPrompt(from data: Data) {
        viewModel.extractMagicPrompt(from: data, preferences: preferences)
    }
}

