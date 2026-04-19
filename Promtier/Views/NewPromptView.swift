//
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers

struct NewPromptView: View {
    private enum ImageImportPolicy {
        static let maxInputBytes = 64 * 1024 * 1024
        static let maxSlots = 3
    }

    var prompt: Prompt?
    var onClose: () -> Void

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @StateObject private var viewModel: NewPromptViewModel

    @StateObject private var titleHoister = TextHoister()
    @StateObject private var contentHoister = TextHoister()
    @StateObject private var promptDescriptionHoister = TextHoister()

    var title: String {
        get { titleHoister.fastText }
        nonmutating set { titleHoister.updateFast(newValue) }
    }
    var content: String {
        get { contentHoister.fastText }
        nonmutating set { contentHoister.updateFast(newValue) }
    }
    var promptDescription: String {
        get { promptDescriptionHoister.fastText }
        nonmutating set { promptDescriptionHoister.updateFast(newValue) }
    }

    var titleBinding: Binding<String> { Binding(get: { title }, set: { title = $0 }) }
    var contentBinding: Binding<String> { Binding(get: { content }, set: { content = $0 }) }
    var promptDescriptionBinding: Binding<String> { Binding(get: { promptDescription }, set: { promptDescription = $0 }) }

    var negativePrompt: String {
        get { viewModel.negativePrompt }
        nonmutating set { viewModel.negativePrompt = newValue }
    }
    var alternatives: [String] {
        get { viewModel.alternatives }
        nonmutating set { viewModel.alternatives = newValue }
    }
    var selectedFolder: String? {
        get { viewModel.selectedFolder }
        nonmutating set { viewModel.selectedFolder = newValue }
    }
    var isFavorite: Bool {
        get { viewModel.isFavorite }
        nonmutating set { viewModel.isFavorite = newValue }
    }
    var selectedIcon: String? {
        get { viewModel.selectedIcon }
        nonmutating set { viewModel.selectedIcon = newValue }
    }
    var showcaseImages: [Data] {
        get { viewModel.showcaseImages }
        nonmutating set { viewModel.showcaseImages = newValue }
    }
    var tags: [String] {
        get { viewModel.tags }
        nonmutating set { viewModel.tags = newValue }
    }
    var newTag: String {
        get { viewModel.newTag }
        nonmutating set { viewModel.newTag = newValue }
    }
    var targetAppBundleIDs: [String] {
        get { viewModel.targetAppBundleIDs }
        nonmutating set { viewModel.targetAppBundleIDs = newValue }
    }
    var customShortcut: String? {
        get { viewModel.customShortcut }
        nonmutating set { viewModel.customShortcut = newValue }
    }
    var showingPremiumFor: String? {
        get { viewModel.showingPremiumFor }
        nonmutating set { viewModel.showingPremiumFor = newValue }
    }
    var showingMagicOptions: Bool {
        get { viewModel.showingMagicOptions }
        nonmutating set { viewModel.showingMagicOptions = newValue }
    }
    var branchMessage: String? {
        get { viewModel.branchMessage }
        nonmutating set { viewModel.branchMessage = newValue }
    }
    var isAutocompleting: Bool {
        get { viewModel.isAutocompleting }
        nonmutating set { viewModel.isAutocompleting = newValue }
    }
    var isCategorizing: Bool {
        get { viewModel.isCategorizing }
        nonmutating set { viewModel.isCategorizing = newValue }
    }
    var showNegativeField: Bool {
        get { viewModel.showNegativeField }
        nonmutating set { viewModel.showNegativeField = newValue }
    }
    var showAlternativeField: Bool {
        get { viewModel.showAlternativeField }
        nonmutating set { viewModel.showAlternativeField = newValue }
    }
    var magicCommand: String {
        get { viewModel.magicCommand }
        nonmutating set { viewModel.magicCommand = newValue }
    }
    var magicTarget: MagicTarget {
        get { viewModel.magicTarget }
        nonmutating set { viewModel.magicTarget = newValue }
    }
    var isGeneratingAlternativeDirect: Bool {
        get { viewModel.isGeneratingAlternativeDirect }
        nonmutating set { viewModel.isGeneratingAlternativeDirect = newValue }
    }
    var originalPrompt: Prompt? {
        get { viewModel.originalPrompt }
        nonmutating set { viewModel.originalPrompt = newValue }
    }

    private func vmBinding<T>(_ keyPath: ReferenceWritableKeyPath<NewPromptViewModel, T>) -> Binding<T> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    @State private var isSaving = false
    @State private var showingZenEditor = false
    @State private var zenTarget: ZenEditorTarget? = nil

    enum ZenEditorTarget: Identifiable, Equatable {
        case main
        case negative
        case alternative(Int)

        var id: String {
            switch self {
            case .main: return "main"
            case .negative: return "negative"
            case .alternative(let i): return "alt-\(i)"
            }
        }

        func title(for promptTitle: String, language: AppLanguage) -> String {
            switch self {
            case .main: return promptTitle.isEmpty ? "new_prompt".localized(for: language) : promptTitle
            case .negative: return "negative_prompt".localized(for: language)
            case .alternative(let i): return "\("alternative".localized(for: language)) #\(i + 1)"
            }
        }
    }

    @State private var showingIconPicker = false
    @State private var draggedImageIndex: Int? = nil
    @State private var showingFullScreenImage: Data? = nil

    @State private var showingTagEditor: Bool = false
    @State private var showingCloseAlert: Bool = false
    @State private var selectedImageIndex: Int = 0 // Track which image is selected for spacebar preview

    @State private var insertionRequest: String? = nil
    @State private var replaceSnippetRequest: String? = nil
    @State private var showSnippets: Bool = false
    @State private var snippetSearchQuery: String = ""
    @State private var snippetSelectedIndex: Int = 0
    @State private var triggerSnippetSelection: Bool = false

    @State private var showVariables: Bool = false
    @State private var variablesSelectedIndex: Int = 0
    @State private var triggerVariablesSelection: Bool = false

    @State private var triggerAIRequest: String? = nil
    @State private var selectedRange: NSRange? = nil
    @State private var selectedNegativeRange: NSRange? = nil
    @State private var selectedAlternativeRanges: [NSRange?] = Array(repeating: nil, count: 10)
    @State private var aiResult: AIResult? = nil
    @State private var aiNegativeResult: AIResult? = nil
    @State private var aiAlternativeResults: [AIResult?] = Array(repeating: nil, count: 10)
    @State private var isAIActive: Bool = false
    @State private var activeGeneratingID: String? = nil
    @State private var showParticles: Bool = false
    @State private var showingVersionHistory: Bool = false
    @State private var focusNegative: Bool = false
    @State private var focusAlternative: Bool = false
    @State private var showingShortcutHelp: Bool = false
    @State private var localMonitor: Any? = nil
    struct DiffComparison: Identifiable {
        let id = UUID()
        let text1: String
        let text2: String
        let title1: String
        let title2: String
    }

    @State private var diffComparison: DiffComparison? = nil

    // Identificador para rastrear cambios y guardar borradores
    @State private var isDraftRestored = false
    /// Guard que impide que un auto-guardado pendiente se ejecute después de descartar
    @State private var isDiscarding: Bool = false
    
    @State private var isPinned = false

    private var zenBindingContent: Binding<String> {
        Binding(
            get: {
                switch zenTarget {
                case .main: return content
                case .negative: return negativePrompt
                case .alternative(let i): return i < alternatives.count ? alternatives[i] : ""
                case .none: return ""
                }
            },
            set: { val in
                switch zenTarget {
                case .main: content = val
                case .negative: negativePrompt = val
                case .alternative(let i): if i < alternatives.count { alternatives[i] = val }
                case .none: break
                }
            }
        )
    }

    private var zenBindingTitle: Binding<String> {
        Binding(
            get: {
                switch zenTarget {
                case .main: return title
                case .negative: return "negative_prompt".localized(for: preferences.language)
                case .alternative(let i): return "\("alternative".localized(for: preferences.language)) #\(i + 1)"
                case .none: return ""
                }
            },
            set: { val in
                if case .main = zenTarget {
                    title = val
                }
            }
        )
    }

    private var isAIAvailable: Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }
    
    private var zenBindingSelection: Binding<NSRange?> {
        Binding(
            get: {
                switch zenTarget {
                case .main: return selectedRange
                case .negative: return selectedNegativeRange
                case .alternative(let i): return i < selectedAlternativeRanges.count ? selectedAlternativeRanges[i] : nil
                case .none: return nil
                }
            },
            set: { val in
                switch zenTarget {
                case .main: selectedRange = val
                case .negative: selectedNegativeRange = val
                case .alternative(let i): if i < selectedAlternativeRanges.count { selectedAlternativeRanges[i] = val }
                case .none: break
                }
            }
        )
    }

    private var zenTargetIndex: Int {
        if case .alternative(let i) = zenTarget { return i }
        return 0
    }

    private var zenBindingAIResult: Binding<AIResult?> {
        Binding(
            get: {
                switch zenTarget {
                case .main: return aiResult
                case .negative: return aiNegativeResult
                case .alternative(let i): return i < aiAlternativeResults.count ? aiAlternativeResults[i] : nil
                case .none: return nil
                }
            },
            set: { val in
                switch zenTarget {
                case .main: aiResult = val
                case .negative: aiNegativeResult = val
                case .alternative(let i): if i < aiAlternativeResults.count { aiAlternativeResults[i] = val }
                case .none: break
                }
            }
        )
    }

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : (selectedFolder == nil ? .gray : Color.blue)
    }

    private var currentCategoryColor: Color {
        if let folderName = selectedFolder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .gray
        }
        return .gray
    }

    // Propiedad calculada para saber si el prompt está vacío
    private var isContentEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        alternatives.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) &&
        promptDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        showcaseImages.isEmpty
    }

    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: NewPromptViewModel(prompt: prompt))
    }

    @ViewBuilder
    private func mainScrollViewContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Invisible button for Global Shortcuts
            Button("") {
                autocompletePromptContent()
            }
            .keyboardShortcut("j", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

            // SEC 1: MAIN
            EditorCard(
                title: titleBinding,
                content: contentBinding,
                promptDescription: promptDescriptionBinding,
                isFavorite: vmBinding(\.isFavorite),
                selectedFolder: vmBinding(\.selectedFolder),
                selectedIcon: vmBinding(\.selectedIcon),
                fallbackIconName: selectedFolder.flatMap { PredefinedCategory.fromString($0)?.icon } ?? "doc.text.fill",
                showingIconPicker: $showingIconPicker,
                showingZenEditor: $showingZenEditor,
                zenTarget: $zenTarget,
                showingPremiumFor: vmBinding(\.showingPremiumFor),
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
                    get: { activeGeneratingID == "main" },
                    set: { val in activeGeneratingID = val ? "main" : nil }
                ),
                isAutocompleting: isAutocompleting,
                isCategorizing: isCategorizing,
                onMagicAutocomplete: { autocompletePromptContent() },
                onMagicCategorize: { autoCategorizePrompt() },
                selectedRange: $selectedRange,
                aiResult: $aiResult,
                originalPrompt: originalPrompt,
                prompt: prompt,
                branchMessage: vmBinding(\.branchMessage),
                editorID: "main",
                currentCategoryColor: currentCategoryColor
            )
            .frame(minHeight: geometry.size.height * 0.98)
            
            Spacer().frame(height: 20)

            // SECTION 2: ADVANCED FIELDS
            if preferences.showAdvancedFields || !negativePrompt.isEmpty || alternatives.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                PromptAdvancedFieldsView(
                    negativePrompt: vmBinding(\.negativePrompt),
                    alternatives: vmBinding(\.alternatives),
                    content: contentBinding,
                    branchMessage: vmBinding(\.branchMessage),
                    focusNegative: $focusNegative,
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
                    activeGeneratingID: $activeGeneratingID,
                    selectedNegativeRange: $selectedNegativeRange,
                    aiNegativeResult: $aiNegativeResult,
                    showingPremiumFor: vmBinding(\.showingPremiumFor),
                    isGeneratingAlternativeDirect: vmBinding(\.isGeneratingAlternativeDirect),
                    themeColor: themeColor,
                    currentCategoryColor: currentCategoryColor,
                    preferences: preferences,
                    isAIAvailable: isAIAvailable,
                    canGenerateAlternative: !contentHoister.slowText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    originalPrompt: originalPrompt,
                    prompt: prompt,
                    onZenNegative: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            zenTarget = .negative
                            showingZenEditor = true
                        }
                    },
                    onCompareNegative: {
                        diffComparison = DiffComparison(
                            text1: content,
                            text2: negativePrompt,
                            title1: "main_content".localized(for: preferences.language),
                            title2: "negative_prompt".localized(for: preferences.language)
                        )
                    },
                    onGenerateAlternativeDirect: generateAlternativeDirect,
                    onAlternativeRow: { index in
                        AnyView(alternativeRow(index: index))
                    }
                )
            }

            Spacer().frame(height: 20)

            // SECTION 3: UTILITIES
            VStack(alignment: .leading, spacing: 20) {
                // Atajo Individual (Movido aquí para mayor visibilidad)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeColor)
                        Text("shortcut".uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        Button(action: { showingShortcutHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingShortcutHelp) {
                            helpPopover(title: "shortcut_help", content: "shortcut_help_desc")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        if preferences.isPremiumActive {
                            HStack {
                                Text("global_shortcut_copy".localized(for: preferences.language))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))
                                Spacer()
                                ReusableShortcutRecorderView(title: "", shortcutString: vmBinding(\.customShortcut))
                            }
                        } else {
                            // Mostrar locked state para transparencia
                            HStack {
                                Label("global_shortcut_copy".localized(for: preferences.language), systemImage: "lock.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("unlock".localized(for: preferences.language)) {
                                    showingPremiumFor = "global_shortcut_copy".localized(for: preferences.language)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.04) : Color.primary.opacity(0.01))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.12) : Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )
                }

                PromptTagsEditorView(
                    tags: vmBinding(\.tags),
                    newTag: vmBinding(\.newTag),
                    showingTagEditor: $showingTagEditor,
                    preferences: preferences
                )

                // Contextual Awareness (App Association)
                PromptAppTargetsView(
                    targetAppBundleIDs: vmBinding(\.targetAppBundleIDs),
                    themeColor: themeColor,
                    currentCategoryColor: currentCategoryColor,
                    preferences: preferences,
                    promptService: promptService
                )

                // Prompt Results (Extracted Component)
                PromptImageShowcaseView(
                    showcaseImages: vmBinding(\.showcaseImages),
                    draggedImageIndex: $draggedImageIndex,
                    showingFullScreenImage: $showingFullScreenImage,
                    selectedImageIndex: $selectedImageIndex,
                    branchMessage: vmBinding(\.branchMessage),
                    preferences: preferences,
                    themeColor: themeColor
                )
                    .padding(.horizontal, 4)
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func alternativeRow(index: Int) -> some View {
        SecondaryEditorCard(
            title: "\("alternative".localized(for: preferences.language)) #\(index + 1)",
            placeholder: "alternative_prompt_placeholder".localized(for: preferences.language),
            text: Binding(
                get: { alternatives.indices.contains(index) ? alternatives[index] : "" },
                set: { if alternatives.indices.contains(index) { alternatives[index] = $0 } }
            ),
            icon: "arrow.triangle.2.circlepath",
            color: currentCategoryColor,
            onZenMode: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    zenTarget = .alternative(index)
                    showingZenEditor = true
                }
            },
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
                get: { activeGeneratingID == "alt-\(index)" },
                set: { val in activeGeneratingID = val ? "alt-\(index)" : nil }
            ),
            selectedRange: Binding(
                get: { index < selectedAlternativeRanges.count ? selectedAlternativeRanges[index] : nil },
                set: { if index < selectedAlternativeRanges.count { selectedAlternativeRanges[index] = $0 } }
            ),
            aiResult: Binding(
                get: { index < aiAlternativeResults.count ? aiAlternativeResults[index] : nil },
                set: { if index < aiAlternativeResults.count { aiAlternativeResults[index] = $0 } }
            ),
            showingPremiumFor: vmBinding(\.showingPremiumFor),
            originalPrompt: originalPrompt,
            prompt: prompt,
            branchMessage: vmBinding(\.branchMessage),
            editorID: "alt-\(index)",
            currentCategoryColor: currentCategoryColor
        ) {
            HStack(spacing: 10) {
                if !alternatives[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Action: Swap
                    Button(action: {
                        withAnimation {
                            let temp = content
                            content = alternatives[index]
                            alternatives[index] = temp
                            branchMessage = "Content swapped!"
                        }
                        HapticService.shared.playLight()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { branchMessage = nil } }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(themeColor)
                    .help("Swap with main prompt")

                    // Action: Merge
                    Button(action: {
                        withAnimation {
                            if !content.isEmpty { content += "\n\n---\n\n" }
                            content += alternatives[index]
                            alternatives[index] = ""
                            branchMessage = "Merged into main!"
                        }
                        HapticService.shared.playLight()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { branchMessage = nil } }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(themeColor)
                    .help("Merge into main prompt")

                    // Action: Branching
                    Button(action: {
                        let newTitle = title.isEmpty ? "Alternative Branch" : "\(title) (Branch)"
                        let newPrompt = Prompt(
                            title: newTitle,
                            content: alternatives[index],
                            folder: selectedFolder,
                            tags: tags
                        )
                        _ = promptService.createPrompt(newPrompt)
                        HapticService.shared.playSuccess()
                        branchMessage = "Prompt branched successfully!"

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            branchMessage = nil
                            DraftService.shared.clearDraft()
                            
                            // Navegar a la carpeta/lista principal
                            promptService.searchQuery = ""
                            if let folder = selectedFolder {
                                promptService.selectedCategory = folder
                            } else {
                                promptService.selectedCategory = nil
                            }
                            
                            MenuBarManager.shared.isModalActive = false
                            onClose() // Salir a la lista
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.purple)
                    .help("Create a new prompt from this alternative")

                    // Action: Diff
                    Button(action: {
                        diffComparison = DiffComparison(
                            text1: content,
                            text2: alternatives[index],
                            title1: "main_content".localized(for: preferences.language),
                            title2: "\("alternative".localized(for: preferences.language)) #\(index + 1)"
                        )
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right.text.vertical")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                    .help("Compare with main prompt")
                }

                // Action: Remove
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        _ = alternatives.remove(at: index)
                    }
                    HapticService.shared.playLight()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Remove alternative")
            }
        }
    }

    private var fullScreenImageSheetItem: Binding<IdentifiableData?> {
        Binding(
            get: { showingFullScreenImage.map { IdentifiableData(value: $0) } },
            set: { showingFullScreenImage = $0?.value }
        )
    }

    private var premiumSheetItem: Binding<IdentifiableString?> {
        Binding(
            get: { showingPremiumFor.map { IdentifiableString(value: $0) } },
            set: { showingPremiumFor = $0?.value }
        )
    }

    private struct DraftState: Equatable {
        let title: String
        let content: String
        let negativePrompt: String
        let alternatives: [String]
        let promptDescription: String
        let selectedFolder: String?
        let isFavorite: Bool
        let selectedIcon: String?
        let showcaseImages: [Data]
        let tags: [String]
        let customShortcut: String?
        let targetAppBundleIDs: [String]
        let isContentEmpty: Bool
    }

    private var draftState: DraftState {
        DraftState(
            title: title,
            content: content,
            negativePrompt: negativePrompt,
            alternatives: alternatives,
            promptDescription: promptDescription,
            selectedFolder: selectedFolder,
            isFavorite: isFavorite,
            selectedIcon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            customShortcut: customShortcut,
            targetAppBundleIDs: targetAppBundleIDs,
            isContentEmpty: isContentEmpty
        )
    }

    private var hasUnsavedChanges: Bool {
        if let existingPrompt = originalPrompt ?? prompt {
            var existingAlts = existingPrompt.alternatives
            if existingAlts.isEmpty, let legacy = existingPrompt.alternativePrompt, !legacy.isEmpty {
                existingAlts = [legacy]
            }
            
            let existingDesc = (existingPrompt.promptDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let currentDesc = promptDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let existingNeg = (existingPrompt.negativePrompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let currentNeg = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return existingPrompt.title != title ||
                   existingPrompt.content != content ||
                   existingDesc != currentDesc ||
                   existingPrompt.folder != selectedFolder ||
                   existingPrompt.isFavorite != isFavorite ||
                   existingPrompt.icon != selectedIcon ||
                   existingPrompt.showcaseImages != showcaseImages ||
                   existingNeg != currentNeg ||
                   existingAlts != alternatives ||
                   existingPrompt.tags != tags ||
                   existingPrompt.targetAppBundleIDs != targetAppBundleIDs ||
                   existingPrompt.customShortcut != customShortcut
        } else {
            // Para un prompt nuevo, solo consideramos que hay cambios sin guardar
            // si el usuario realmente ha escrito un título o contenido explícito.
            let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isContentTextEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if isTitleEmpty && isContentTextEmpty {
                return false
            }
            return !isContentEmpty
        }
    }

    private func saveAsDraft() {
        // Solo cuando creamos un prompt nuevo: "draft" significa guardar como uncategorized ("Sin categoría").
        // En modo edición, no queremos moverlo de su carpeta.
        if originalPrompt == nil {
            if title.isEmpty {
                let prefix = "draft_prefix".localized(for: preferences.language)
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: preferences.language.rawValue)
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                title = "\(prefix) - \(formatter.string(from: Date()))"
            }
            selectedFolder = nil
        }
        savePrompt(closeAfter: true)
    }

    private func discardChanges() {
        // Cancelar inmediatamente cualquier auto-guardado pendiente para que no
        // se ejecute después de que el usuario haya elegido Descartar.
        isDiscarding = true
        DraftService.shared.clearDraft()
        MenuBarManager.shared.isModalActive = false
        onClose()
    }

    var body: some View {
        GeometryReader { geometry in
            let _ = titleHoister.slowText
            let _ = contentHoister.slowText
            let _ = promptDescriptionHoister.slowText
            let targetWidth = geometry.size.width * 0.9

            VStack(spacing: 0) {
                NewPromptHeaderView(
                    title: title,
                    content: content,
                    promptDescription: promptDescription,
                    showcaseImages: showcaseImages,
                    originalPrompt: originalPrompt,
                    prompt: prompt,
                    currentCategoryColor: currentCategoryColor,
                    themeColor: themeColor,
                    hasUnsavedChanges: hasUnsavedChanges,
                    showingCloseAlert: $showingCloseAlert,
                    showingVersionHistory: $showingVersionHistory,
                    showingPremiumFor: vmBinding(\.showingPremiumFor),
                    isPinned: $isPinned,
                    branchMessage: vmBinding(\.branchMessage),
                    discardChanges: { discardChanges() },
                    saveCurrentDraft: { saveCurrentDraft() },
                    branchPrompt: { branchPrompt() },
                    savePrompt: { savePrompt() },
                    closePopover: { MenuBarManager.shared.closePopover() }
                )

                ScrollView(showsIndicators: false) {
                    ScrollViewReader { proxy in
                        mainScrollViewContent(geometry: geometry)
                            .frame(width: targetWidth)
                            .frame(maxWidth: .infinity)
                            .onChange(of: focusNegative) { _, isFocused in
                                if isFocused {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            proxy.scrollTo("negative_prompt_section", anchor: .center)
                                        }
                                    }
                                }
                            }
                            .onChange(of: focusAlternative) { _, isFocused in
                                if isFocused {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            proxy.scrollTo("alternatives_section", anchor: .center)
                                        }
                                    }
                                }
                            }
                    }
                }
                .onTapGesture {
                    // Click outside any focused field should resign focus
                    if let window = NSApp.keyWindow {
                        window.makeFirstResponder(nil)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundView)
        .sheet(item: fullScreenImageSheetItem) { item in
            FullScreenImageView(imageData: item.value)
                .onDisappear {
                    MenuBarManager.shared.fixTransientState()
                }
        }
        .overlay { overlays }
                .sheet(item: premiumSheetItem) { item in
                    PremiumUpsellView(featureName: item.value)
                }
                .sheet(item: $diffComparison) { comparison in
                    DiffView(
                        text1: comparison.text1,
                        text2: comparison.text2,
                        title1: comparison.title1,
                        title2: comparison.title2
                    )
                }
                .sheet(isPresented: $showingVersionHistory) {
                    if let snapHistory = originalPrompt?.versionHistory {
                        VersionHistoryView(
                            snapshots: snapHistory,
                            currentContent: content,
                            onRestore: { snap in
                                withAnimation(.spring()) {
                                    self.title = snap.title
                                    self.content = snap.content
                                    self.negativePrompt = snap.negativePrompt ?? ""
                                    self.alternatives = snap.alternatives
                                    
                                    // Actualizar visibilidad de campos opcionales
                                    if !self.negativePrompt.isEmpty { self.showNegativeField = true }
                                    if !self.alternatives.isEmpty { self.showAlternativeField = true }
                                }
                                showingVersionHistory = false
                                HapticService.shared.playSuccess()
                            }
                        )
                    }
                }
                .alert("unsaved_changes_title".localized(for: preferences.language), isPresented: $showingCloseAlert) {
                    if originalPrompt == nil && prompt == nil {
                        Button("save_as_draft".localized(for: preferences.language), action: saveAsDraft)
                    }
                    Button("discard".localized(for: preferences.language), role: .destructive, action: discardChanges)
                    Button("cancel".localized(for: preferences.language), role: .cancel) { }
                } message: {
                    Text("unsaved_changes_message".localized(for: preferences.language))
                }
        .onAppear {
            setupOnAppear()
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            // Cancelar auto-guardado pendiente al salir de la vista
            MenuBarManager.shared.isModalActive = false
        }
        .onChange(of: draftState) { _, _ in
            saveCurrentDraft()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FloatingZenDraftUpdated"))) { _ in
            DispatchQueue.main.async {
                self.setupOnAppear()
            }
        }
        .onReceive(viewModel.$title.dropFirst()) { _ in
            syncHoistedFieldsFromViewModel()
        }
        .onReceive(viewModel.$content.dropFirst()) { _ in
            syncHoistedFieldsFromViewModel()
        }
        .onReceive(viewModel.$promptDescription.dropFirst()) { _ in
            syncHoistedFieldsFromViewModel()
        }
    }

    private func dismissSnippetsOverlay() {
        withAnimation { showSnippets = false }
    }

    private func dismissVariablesOverlay() {
        withAnimation { showVariables = false }
    }

    @ViewBuilder
    private var overlays: some View {
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
                        get: { activeGeneratingID == (zenTarget == .main ? "main" : (zenTarget == .negative ? "negative" : "alt-\(zenTargetIndex)")) },
                        set: { val in
                            if !val { activeGeneratingID = nil }
                        }
                    ),
                    selectedRange: zenBindingSelection,
                    aiResult: zenBindingAIResult,
                    showingPremiumFor: vmBinding(\.showingPremiumFor),
                    originalPrompt: originalPrompt,
                    branchMessage: vmBinding(\.branchMessage)
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
            magicOptionsOverlayLayer

            if let msg = branchMessage {
                VStack {
                    Spacer()
                    if msg == "ai_thinking".localized(for: preferences.language) {
                        AnimatedThinkingText(baseText: msg.replacingOccurrences(of: "...", with: ""))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.purple)
                                    .shadow(radius: 10)
                            )
                            .padding(.bottom, 40)
                    } else {
                        Text(msg)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(msg.hasPrefix("❌") ? Color.red : Color.purple)
                                    .shadow(radius: 10)
                            )
                            .padding(.bottom, 40)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(400)
            }
        }
    }

    private var snippetsOverlayLayer: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { dismissSnippetsOverlay() }
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
                .onTapGesture { dismissVariablesOverlay() }
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

                private var magicOptionsOverlayLayer: some View {
                    ZStack {
                        // Fondo oscuro semi-transparente que bloquea toques
                        Color.black.opacity(showingMagicOptions ? 0.3 : 0.0)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showingMagicOptions = false } }
                        
                        if showingMagicOptions {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                    Text("Modificar con IA")
                                        .font(.system(size: 18, weight: .bold))
                                    Spacer()
                                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showingMagicOptions = false } }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("¿Qué deseas modificar?")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    
                                                            HStack(spacing: 8) {
                                                                ForEach(MagicTarget.allCases) { target in
                                                                    Button(action: { magicTarget = target }) {
                                                                        Text(target.rawValue)
                                                                            .font(.system(size: 13, weight: magicTarget == target ? .semibold : .regular))
                                                                            .padding(.horizontal, 16)
                                                                            .padding(.vertical, 6)
                                                                            .frame(maxWidth: .infinity)
                                                                            .background(
                                                                                RoundedRectangle(cornerRadius: 8)
                                                                                    .fill(magicTarget == target ? Color.blue : Color.primary.opacity(0.05))
                                                                            )
                                                                            .foregroundColor(magicTarget == target ? .white : .primary)
                                                                            .overlay(
                                                                                RoundedRectangle(cornerRadius: 8)
                                                                                    .stroke(magicTarget == target ? Color.blue : Color.primary.opacity(0.1), lineWidth: 1)
                                                                            )
                                                                    }
                                                                    .buttonStyle(.plain)
                                                                }
                                                            }                                }
                                
                                if magicTarget == .content {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Instrucciones")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            
                                        TextField("Ej: Haz el texto más amigable...", text: vmBinding(\.magicCommand), axis: .vertical)
                                            .textFieldStyle(.plain)
                                            .padding(12)
                                            .background(Color(NSColor.controlBackgroundColor))
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                            .lineLimit(3...6)
                                            .onSubmit { executeMagicWithCommand() }
                                            .onAppear {
                                                magicCommand = ""
                                            }
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Se generará automáticamente un nuevo texto para \(magicTarget.rawValue) basado en el contenido existente.")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
            
                                HStack {
                                    Spacer()
                                    Button("Modificar") { executeMagicWithCommand() }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.large)
                                        .disabled(magicTarget == .content && magicCommand.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding(24)
                            .frame(width: 450)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.2), radius: 40, x: 0, y: 20)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(showingMagicOptions)
                    .zIndex(202)
    }

    private func setupKeyboardMonitor() {
        if localMonitor != nil { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Navegación por teclado dentro de overlays (Variables / Snippets)
            // Esto asegura que las flechas sigan funcionando incluso si el foco se va al popover.
            if self.showVariables {
                switch event.keyCode {
                case 126: // Up Arrow
                    DispatchQueue.main.async {
                        self.variablesSelectedIndex = max(0, self.variablesSelectedIndex - 1)
                    }
                    return nil
                case 125: // Down Arrow
                    DispatchQueue.main.async {
                        self.variablesSelectedIndex += 1
                    }
                    return nil
                case 36, 76: // Return / Enter
                    DispatchQueue.main.async {
                        self.triggerVariablesSelection = true
                    }
                    return nil
                default:
                    break
                }
            }

            if self.showSnippets {
                switch event.keyCode {
                case 126: // Up Arrow
                    DispatchQueue.main.async {
                        self.snippetSelectedIndex = max(0, self.snippetSelectedIndex - 1)
                    }
                    return nil
                case 125: // Down Arrow
                    DispatchQueue.main.async {
                        self.snippetSelectedIndex += 1
                    }
                    return nil
                case 36, 76: // Return / Enter
                    DispatchQueue.main.async {
                        self.triggerSnippetSelection = true
                    }
                    return nil
                default:
                    break
                }
            }

            // Image Gallery Navigation (Left/Right) when no focus
            if !self.showcaseImages.isEmpty && (NSApp.keyWindow?.firstResponder is NSTextView == false && NSApp.keyWindow?.firstResponder is NSTextField == false) {
                if event.keyCode == 123 { // Left Arrow
                    DispatchQueue.main.async {
                        self.selectedImageIndex = max(0, self.selectedImageIndex - 1)
                        // Sync with full screen preview if it's active
                        if self.showingFullScreenImage != nil {
                            self.showingFullScreenImage = self.showcaseImages[self.selectedImageIndex]
                        }
                    }
                    return nil
                }
                if event.keyCode == 124 { // Right Arrow
                    DispatchQueue.main.async {
                        self.selectedImageIndex = min(self.showcaseImages.count - 1, self.selectedImageIndex + 1)
                        // Sync with full screen preview if it's active
                        if self.showingFullScreenImage != nil {
                            self.showingFullScreenImage = self.showcaseImages[self.selectedImageIndex]
                        }
                    }
                    return nil
                }
            }

            // Spacebar -> Toggle Preview of selected image
            if event.keyCode == 49 { // Space
                // Check if any text field has focus
                let hasFocus = NSApp.keyWindow?.firstResponder is NSTextView || NSApp.keyWindow?.firstResponder is NSTextField
                
                if !hasFocus || self.showingFullScreenImage != nil {
                    DispatchQueue.main.async {
                        if self.showingFullScreenImage != nil {
                            withAnimation(.spring(response: 0.3)) {
                                self.showingFullScreenImage = nil
                            }
                        } else if !self.showcaseImages.isEmpty {
                            let idx = min(self.selectedImageIndex, self.showcaseImages.count - 1)
                            withAnimation(.spring(response: 0.35)) {
                                self.showingFullScreenImage = self.showcaseImages[idx]
                            }
                            if self.preferences.soundEnabled { SoundService.shared.playPreviewSound() }
                        }
                    }
                    return nil
                }
            }

            // Cmd + S -> Save
            if modifiers.contains(.command) && event.keyCode == 1 { // 'S' is key code 1
                DispatchQueue.main.async {
                    let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedContent = self.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard !trimmedTitle.isEmpty && !trimmedContent.isEmpty else {
                        HapticService.shared.playError()
                        withAnimation {
                            self.branchMessage = "required_fields".localized(for: self.preferences.language)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { if self.branchMessage == "required_fields".localized(for: self.preferences.language) { self.branchMessage = nil } }
                        }
                        return
                    }

                    if self.showingZenEditor {
                        self.savePrompt(closeAfter: false)
                        withAnimation(.spring()) {
                            self.zenTarget = nil
                            self.showingZenEditor = false
                        }
                    } else {
                        self.savePrompt()
                    }
                }
                return nil // consume the event
            }

            // Cmd + C -> Copy (Fallback to entire content if no selection)
            if modifiers == .command && event.keyCode == 8 { // 'C' is keyCode 8
                if isTextSelectedInEditor() {
                    return event // Let the text field copy the selection
                }
                
                // Si no hay selección, copiar el contenido del draft
                if !content.isEmpty {
                    DispatchQueue.main.async {
                        ClipboardService.shared.copyToClipboard(content)
                        if preferences.soundEnabled { SoundService.shared.playCopySound() }
                        HapticService.shared.playLight()
                    }
                    return nil
                }
            }

            // Cmd + V -> Paste Image globally
            if modifiers == .command && event.keyCode == 9 { // 'V' is keyCode 9
                guard self.showcaseImages.count < ImageImportPolicy.maxSlots else {
                    self.showImageImportWarning(self.imageSlotsFullMessage)
                    return nil
                }
                let pb = NSPasteboard.general
                // Check if the primary item is an image
                if let types = pb.types, types.contains(where: { $0.rawValue.starts(with: "public.image") || $0 == .png || $0 == .tiff }) {
                    if let pbData = pb.data(forType: .png) ?? pb.data(forType: .tiff) ?? pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                        appendOptimizedImageData(pbData, at: nil)
                        return nil // Consume event
                    } else if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                        DispatchQueue.global(qos: .userInitiated).async {
                            guard let tiffData = image.tiffRepresentation,
                                  let bitmap = NSBitmapImageRep(data: tiffData),
                                  let jpData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }

                            self.appendOptimizedImageData(jpData, at: nil)
                        }
                        return nil // Consume event
                    }
                }
            }

            // ESC (KeyCode 53) -> Cerrar o salir de overlays
            if event.keyCode == 53 {
                if self.showingMagicOptions {
                    DispatchQueue.main.async { withAnimation { self.showingMagicOptions = false } }
                    return nil
                }
                if self.showSnippets {
                    DispatchQueue.main.async { self.dismissSnippetsOverlay() }
                    return nil
                }
                if self.showVariables {
                    DispatchQueue.main.async { self.dismissVariablesOverlay() }
                    return nil
                }

                // Si no hay overlays críticos abiertos, primero perdemos foco. Si no hay foco, cerramos
                if self.zenTarget == nil && !self.showingIconPicker {
                    if let window = NSApp.keyWindow, let firstResponder = window.firstResponder {
                        // In SwiftUI text fields, the firstResponder is often an NSTextView known as the field editor
                        let isEditingText = firstResponder is NSTextView || firstResponder.className.contains("TextEditor")

                        // We check if it's actually editing something by seeing if making it resign does anything
                        if isEditingText {
                            DispatchQueue.main.async {
                                // This attempts to commit any current text editing and resign focus
                                _ = window.makeFirstResponder(nil)
                            }
                            return nil // We consumed the event, just losing focus, NO closing the window
                        }
                    }

                    // Si no estamos editando nada y presionan ESC, cerramos la ventana
                    DispatchQueue.main.async {
                        if self.hasUnsavedChanges {
                            self.showingCloseAlert = true
                        } else {
                            self.discardChanges()
                        }
                    }
                    return nil
                }

                // Si estamos en ZenMode, salir del modo con animación
                if self.zenTarget != nil {
                    DispatchQueue.main.async {
                        withAnimation(.spring()) {
                            self.zenTarget = nil
                            self.showingZenEditor = false
                        }
                    }
                    return nil
                }
            }

            // Option + N -> Focus Negative Prompt
            if modifiers == .option && event.keyCode == 45 {
                DispatchQueue.main.async {
                    withAnimation(.spring()) {
                        self.showNegativeField = true
                    }
                    // Dar tiempo a que la vista se inserte antes de pedir foco
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.focusNegative = true
                    }
                }
                return nil
            }

            // Option + A -> Focus Alternative Prompt
            if modifiers == .option && event.keyCode == 0 { // keyCode 0 is 'A'
                DispatchQueue.main.async {
                    withAnimation(.spring()) {
                        self.showAlternativeField = true
                    }
                    // Dar tiempo a que la vista se inserte antes de pedir foco
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.focusAlternative = true
                    }
                }
                return nil
            }

            // Option + V -> Insert Variable Popup
            if modifiers == .option && event.keyCode == 9 { // keyCode 9 is 'V'
                DispatchQueue.main.async {
                    if self.preferences.isPremiumActive {
                        withAnimation {
                            self.showVariables.toggle()
                            self.variablesSelectedIndex = 0
                        }
                    } else {
                        self.showingPremiumFor = "dynamic_variables".localized(for: self.preferences.language)
                    }
                }
                return nil
            }

            return event
        }
    }

    private func setupOnAppear() {
        MenuBarManager.shared.isModalActive = false

        let draft = DraftService.shared.loadDraft()

        // Determinar si debemos cargar el draft en lugar del prompt original
        var shouldLoadDraft = false
        if let draft = draft {
            if prompt == nil {
                shouldLoadDraft = true // Draft de un nuevo prompt (asumimos que si no hay prompt activo en UI, queremos el draft)
            } else if let prompt = prompt, draft.prompt.id == prompt.id {
                shouldLoadDraft = true // Draft corresponde al prompt que estamos editando
            } else if draft.isEditing {
                // If it's a draft from editing, and we just got the notification, force load it
                shouldLoadDraft = true
            }
        }

        if shouldLoadDraft, let draft = draft {
            // Restore draft if it exists and matches the current context
            let draftPrompt = draft.prompt

            if draft.isEditing {
                if let original = promptService.prompts.first(where: { $0.id == draftPrompt.id }) {
                    self.originalPrompt = original
                } else if let p = prompt {
                    self.originalPrompt = p
                }
            }

            DispatchQueue.main.async {
                self.title = draftPrompt.title
                self.content = draftPrompt.content
                self.negativePrompt = draftPrompt.negativePrompt ?? ""

                var draftAlternatives = draftPrompt.alternatives
                if draftAlternatives.isEmpty, let legacy = draftPrompt.alternativePrompt, !legacy.isEmpty {
                    draftAlternatives = [legacy]
                }
                self.alternatives = draftAlternatives

                self.promptDescription = draftPrompt.promptDescription ?? ""
                self.selectedFolder = draftPrompt.folder
                self.isFavorite = draftPrompt.isFavorite
                self.selectedIcon = draftPrompt.icon
                self.showcaseImages = draftPrompt.showcaseImages
                self.tags = draftPrompt.tags
                self.targetAppBundleIDs = draftPrompt.targetAppBundleIDs
                self.customShortcut = draftPrompt.customShortcut
                self.isDraftRestored = true

                if !self.negativePrompt.isEmpty { self.showNegativeField = true }
                if !self.alternatives.isEmpty { self.showAlternativeField = true }
                self.syncHoistedFieldsToViewModel()
            }

        } else if let prompt = prompt {
            self.originalPrompt = prompt
            title = prompt.title
            content = prompt.content
            negativePrompt = prompt.negativePrompt ?? ""
            
            var initialAlternatives = prompt.alternatives
            if initialAlternatives.isEmpty, let legacy = prompt.alternativePrompt, !legacy.isEmpty {
                initialAlternatives = [legacy]
            }
            alternatives = initialAlternatives
            
            if !negativePrompt.isEmpty { showNegativeField = true }
            if !alternatives.isEmpty { showAlternativeField = true }
            if alternatives.isEmpty, let legacy = prompt.alternativePrompt, !legacy.isEmpty {
                alternatives = [legacy]
            }
            promptDescription = prompt.promptDescription ?? ""
            selectedFolder = prompt.folder
            isFavorite = prompt.isFavorite
            selectedIcon = prompt.icon
            showcaseImages = prompt.showcaseImages
            tags = prompt.tags
            targetAppBundleIDs = prompt.targetAppBundleIDs
            customShortcut = prompt.customShortcut

            if !negativePrompt.isEmpty { showNegativeField = true }
            if !alternatives.isEmpty { showAlternativeField = true }
            syncHoistedFieldsToViewModel()

            // Lazy-load de imágenes
            if showcaseImages.isEmpty && prompt.showcaseImageCount > 0 {
                Task(priority: .userInitiated) {
                    if let full = await promptService.fetchPrompt(byId: prompt.id, includeImages: true) {
                        await MainActor.run {
                            self.originalPrompt = full
                            if self.showcaseImages.isEmpty {
                                self.showcaseImages = full.showcaseImages
                            }
                        }
                    }
                }
            }
        } else if let activeCategory = promptService.selectedCategory {
            // Autoseleccionar la categoría activa al crear uno nuevo
            selectedFolder = activeCategory
        }
    }

    private func saveCurrentDraft() {
        let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isContentTextEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // No guardar draft de un nuevo prompt vacío (sin title ni contenido útil)
        if originalPrompt == nil && isTitleEmpty && isContentTextEmpty {
            return
        }

        // No guardar si el contenido es idéntico al original que estamos editando
        if let original = originalPrompt {
            let hasChanges = title != original.title ||
                             content != original.content ||
                             promptDescription != (original.promptDescription ?? "") ||
                             selectedFolder != original.folder ||
                             selectedIcon != original.icon ||
                             showcaseImages != original.showcaseImages ||
                             negativePrompt != (original.negativePrompt ?? "") ||
                             alternatives != original.alternatives ||
                             targetAppBundleIDs != original.targetAppBundleIDs ||
                             customShortcut != original.customShortcut
            if !hasChanges { return }
        }

        // Crear un objeto prompt temporal para el borrador
        var draftPrompt = Prompt(
            title: title,
            content: content,
            promptDescription: promptDescription.isEmpty ? nil : promptDescription,
            folder: selectedFolder,
            icon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            targetAppBundleIDs: targetAppBundleIDs,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            alternatives: alternatives,
            customShortcut: customShortcut
        )

        // Si estamos editando, mantenemos el ID original para poder actualizarlo al restaurar
        if let original = originalPrompt {
            draftPrompt.id = original.id
        }

        DraftService.shared.saveDraft(prompt: draftPrompt, isEditing: prompt != nil || originalPrompt != nil)
    }

    // MARK: - Image Import Helpers

    private func appendOptimizedImageData(_ rawData: Data, at index: Int?) {
        DispatchQueue.global(qos: .userInitiated).async {
            if rawData.count > ImageImportPolicy.maxInputBytes {
                self.showImageImportWarning(self.imageTooLargeMessage)
                return
            }
            guard let optimizedData = ImageOptimizer.shared.optimize(imageData: rawData) else {
                self.showImageImportWarning(self.imageUnsupportedMessage)
                return
            }
            DispatchQueue.main.async {
                self.insertImage(optimizedData, at: index)
            }
        }
    }

    private var imageTooLargeMessage: String {
        let format = "image_import_too_large".localized(for: preferences.language)
        return String(format: format, ImageImportPolicy.maxInputBytes / (1024 * 1024))
    }

    private var imageUnsupportedMessage: String {
        "image_import_unsupported".localized(for: preferences.language)
    }

    private var imageSlotsFullMessage: String {
        "image_import_slots_full".localized(for: preferences.language)
    }

    private func showImageImportWarning(_ message: String) {
        DispatchQueue.main.async {
            HapticService.shared.playError()
            withAnimation {
                branchMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                    if branchMessage == message {
                        branchMessage = nil
                    }
                }
            }
        }
    }

    private func insertImage(_ data: Data, at index: Int?) {
        if showcaseImages.count < ImageImportPolicy.maxSlots {
            if let targetIndex = index, targetIndex < showcaseImages.count {
                showcaseImages.insert(data, at: targetIndex)
                selectedImageIndex = targetIndex
            } else {
                showcaseImages.append(data)
                selectedImageIndex = showcaseImages.count - 1
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    private var backgroundView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            if preferences.isHaloEffectEnabled {
                // Círculos decorativos para efecto mesh (Neón sutil y dinámico)
                Circle()
                    .fill(currentCategoryColor.opacity(0.18))
                    .frame(width: 500, height: 500)
                    .blur(radius: 90)
                    .offset(x: 220, y: -150)
                    .animation(.easeInOut(duration: 0.4), value: selectedFolder)

                Circle()
                    .fill(currentCategoryColor.opacity(0.12))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: -250, y: 200)
                    .animation(.easeInOut(duration: 0.4), value: selectedFolder)
            }

            // Brillo ambiental central que cambia con la categoría
            Circle()
                .fill(currentCategoryColor.opacity(0.05))
                .frame(width: 600, height: 600)
                .blur(radius: 120)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFolder)
        }
    }

    private func savePrompt(closeAfter: Bool = true) {
        isSaving = true

        // Limpiar borrador al guardar con éxito (solo si cerramos o es explícito)
        if closeAfter {
            DraftService.shared.clearDraft()
            MenuBarManager.shared.isModalActive = false
        }

        let newNegativePrompt: String? = negativePrompt.isEmpty ? nil : negativePrompt

        // Usar originalPrompt si existe (restaurado de borrador o asignado en onAppear)
        if let existingPrompt = originalPrompt ?? prompt {
            // Verificar si hay cambios de cualquier tipo para evitar guardados redundantes
            let basicChanges = existingPrompt.title != title ||
                             existingPrompt.content != content ||
                             existingPrompt.promptDescription != (promptDescription.isEmpty ? nil : promptDescription) ||
                             existingPrompt.folder != selectedFolder ||
                             existingPrompt.isFavorite != isFavorite ||
                             existingPrompt.icon != selectedIcon ||
                             existingPrompt.showcaseImages != showcaseImages ||
                             existingPrompt.negativePrompt != newNegativePrompt ||
                             existingPrompt.alternatives != alternatives ||
                             existingPrompt.targetAppBundleIDs != targetAppBundleIDs ||
                             existingPrompt.customShortcut != customShortcut

            if !basicChanges {
                if closeAfter { onClose() }
                return
            }

            var updated = existingPrompt

            // ✅ Solo crear snapshot si cambió el Título o el Contenido (Premium)
            if preferences.isPremiumActive {
                let coreChanges = existingPrompt.title != title ||
                                 existingPrompt.content != content ||
                                 existingPrompt.negativePrompt != newNegativePrompt ||
                                 existingPrompt.alternatives != alternatives

                if coreChanges {
                    let snapshot = PromptSnapshot(
                        title:     title,
                        content:   content,
                        negativePrompt: newNegativePrompt,
                        alternatives:   alternatives,
                        timestamp: Date()
                    )
                    var history = existingPrompt.versionHistory
                    history.insert(snapshot, at: 0)
                    if history.count > 20 { history = Array(history.prefix(20)) }
                    updated.versionHistory = history
                }
            }

            updated.title = title
            updated.content = content
            updated.promptDescription = promptDescription.isEmpty ? nil : promptDescription
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.icon = selectedIcon
            updated.showcaseImages = showcaseImages
            updated.tags = tags
            updated.negativePrompt = newNegativePrompt
            updated.alternatives = alternatives
            updated.targetAppBundleIDs = targetAppBundleIDs
            updated.customShortcut = customShortcut
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
            
            // ✅ Actualizar el prompt original para que la UI (botones de historial, etc.) reaccione al instante
            DispatchQueue.main.async {
                self.originalPrompt = updated
            }
        } else {
            var new = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? nil : promptDescription,
                folder: selectedFolder,
                icon: selectedIcon,
                showcaseImages: showcaseImages,
                tags: tags,
                targetAppBundleIDs: targetAppBundleIDs,
                negativePrompt: newNegativePrompt,
                alternatives: alternatives,
                customShortcut: customShortcut
            )
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
        }


        if closeAfter {
            let _ = (originalPrompt ?? prompt) == nil
            
            if preferences.isPremiumActive && preferences.visualEffectsEnabled {
                showParticles = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onClose()
                }
            } else {
                onClose()
            }
        }
    }


    private func branchPrompt() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Asegurarnos de tener los datos actuales (usamos las variables de estado)
        let branchTitle = "\("branch_label".localized(for: preferences.language)): \(title)"
        let newContent = content
        let currentParentID = (originalPrompt ?? prompt)?.id

        var newBranch = Prompt(
            title: branchTitle,
            content: newContent,
            promptDescription: promptDescription,
            folder: selectedFolder,
            icon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            targetAppBundleIDs: targetAppBundleIDs,
            negativePrompt: negativePrompt,
            alternatives: Array(alternatives.prefix(10)),
            customShortcut: nil // Las ramas no heredan el atajo para evitar conflictos
        )

        newBranch.parentID = currentParentID
        newBranch.isFavorite = isFavorite

        if promptService.createPrompt(newBranch) {
            HapticService.shared.playSuccess()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                branchMessage = "branch_created_success".localized(for: preferences.language)
            }
            
            // Esperar a que se lea la notificación y luego simular el "salir" a la lista
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { branchMessage = nil }
                
                DraftService.shared.clearDraft()
                
                // Navegar a la carpeta principal para mostrar la nueva rama
                promptService.searchQuery = ""
                if let folder = selectedFolder {
                    promptService.selectedCategory = folder
                } else {
                    promptService.selectedCategory = nil
                }
                
                MenuBarManager.shared.isModalActive = false
                onClose() // Simular salir para ir a la lista de prompts
            }
        }
    }

    // MARK: - AI Magic Features (ViewModel-backed)

    private func syncHoistedFieldsToViewModel() {
        viewModel.title = title
        viewModel.content = content
        viewModel.promptDescription = promptDescription
    }

    private func syncHoistedFieldsFromViewModel() {
        if viewModel.title != title {
            title = viewModel.title
        }
        if viewModel.content != content {
            content = viewModel.content
        }
        if viewModel.promptDescription != promptDescription {
            promptDescription = viewModel.promptDescription
        }
    }

    private func autocompletePromptContent() {
        syncHoistedFieldsToViewModel()
        viewModel.autocompletePromptContent(preferences: preferences, promptService: promptService)
    }

    private func executeMagicWithCommand() {
        syncHoistedFieldsToViewModel()
        viewModel.executeMagicWithCommand(preferences: preferences)
    }

    private func autoCategorizePrompt() {
        syncHoistedFieldsToViewModel()
        viewModel.autoCategorizePrompt(preferences: preferences, promptService: promptService)
    }

    private func generateAlternativeDirect() {
        syncHoistedFieldsToViewModel()
        viewModel.generateAlternativeDirect(preferences: preferences)
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



// MARK: - Componentes de Soporte de Galería



// MARK: - Components




#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}

// MARK: - AIGeneratingOverlay


struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct IdentifiableData: Identifiable {
    let id = UUID()
    let value: Data
}

extension NewPromptView {
    @ViewBuilder
    private func helpPopover(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.localized(for: preferences.language))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(content.localized(for: preferences.language))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(width: 250)
    }
    
    private func isTextSelectedInEditor() -> Bool {
        guard let window = NSApp.keyWindow,
              let fieldEditor = window.firstResponder as? NSTextView,
              fieldEditor.selectedRange().length > 0 else {
            return false
        }
        return true
    }
}

// MARK: - Animated Thinking Text
struct AnimatedThinkingText: View {
    let baseText: String
    
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let dots = String(repeating: ".", count: dotCount)
        Text("\(baseText)\(dots)")
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
