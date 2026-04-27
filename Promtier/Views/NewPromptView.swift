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

struct NewPromptView: View {
    enum ShortcutKeyCode {
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let returnKey: UInt16 = 36
        static let enterKey: UInt16 = 76
        static let space: UInt16 = 49
        static let escape: UInt16 = 53
        static let keyA: UInt16 = 0
        static let keyC: UInt16 = 8
        static let keyS: UInt16 = 1
        static let keyV: UInt16 = 9
        static let keyN: UInt16 = 45
    }

    var prompt: Prompt?
    var onClose: () -> Void

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @StateObject var viewModel: NewPromptViewModel
    @StateObject var keyboardCoordinator = NewPromptKeyboardCoordinator()
    let shortcutRouter = NewPromptShortcutRouter()

    @StateObject var titleHoister = TextHoister()
    @StateObject var contentHoister = TextHoister()
    @StateObject var promptDescriptionHoister = TextHoister()

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

    var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.title },
            set: { val in
                viewModel.title = val
                titleHoister.updateFast(val)
            }
        )
    }
    var contentBinding: Binding<String> {
        Binding(
            get: { viewModel.content },
            set: { val in
                viewModel.content = val
                contentHoister.updateFast(val)
            }
        )
    }
    var promptDescriptionBinding: Binding<String> {
        Binding(
            get: { viewModel.promptDescription },
            set: { val in
                viewModel.promptDescription = val
                promptDescriptionHoister.updateFast(val)
            }
        )
    }

    var negativePrompt: String {
        get { viewModel.negativePrompt }
        nonmutating set { viewModel.negativePrompt = newValue }
    }
    var alternatives: [String] {
        get { viewModel.alternatives }
        nonmutating set { viewModel.alternatives = newValue }
    }
    var alternativeDescriptions: [String] {
        get { viewModel.alternativeDescriptions }
        nonmutating set { viewModel.alternativeDescriptions = newValue }
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
    var showingAIPrefs: Bool {
        get { viewModel.showingAIPrefs }
        nonmutating set { viewModel.showingAIPrefs = newValue }
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

    func vmBinding<T>(_ keyPath: ReferenceWritableKeyPath<NewPromptViewModel, T>) -> Binding<T> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    @State var isSaving = false
    @State var showingZenEditor = false
    @State var zenTarget: ZenEditorTarget? = nil

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

    @State var showingIconPicker = false
    @State var mediaState = PromptMediaState()

    @State var showingCloseAlert: Bool = false

    @State var insertionRequest: String? = nil
    @State var replaceSnippetRequest: String? = nil
    @State var showSnippets: Bool = false
    @State var snippetSearchQuery: String = ""
    @State var snippetSelectedIndex: Int = 0
    @State var triggerSnippetSelection: Bool = false

    @State var showVariables: Bool = false
    @State var variablesSelectedIndex: Int = 0
    @State var triggerVariablesSelection: Bool = false

    @State var triggerAIRequest: String? = nil
    @State var selectedRange: NSRange? = nil
    @State var selectedNegativeRange: NSRange? = nil
    @State var selectedAlternativeRanges: [NSRange?] = Array(repeating: nil, count: 10)
    @State var aiResult: AIResult? = nil
    @State var aiNegativeResult: AIResult? = nil
    @State var aiAlternativeResults: [AIResult?] = Array(repeating: nil, count: 10)
    @State var isAIActive: Bool = false
    @State var activeGeneratingID: String? = nil
    @State var showParticles: Bool = false
    @State var showingVersionHistory: Bool = false
    @State var focusNegative: Bool = false
    @State var focusAlternative: Bool = false
    @State var showingShortcutHelp: Bool = false
    struct DiffComparison: Identifiable {
        let id = UUID()
        let text1: String
        let text2: String
        let title1: String
        let title2: String
    }

    @State var diffComparison: DiffComparison? = nil

    // Identificador para rastrear cambios y guardar borradores
    @State var isDraftRestored = false
    /// Guard que impide que un auto-guardado pendiente se ejecute después de descartar
    @State var isDiscarding: Bool = false
    
    @State var isPinned = false

    var zenBindingContent: Binding<String> {
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

    var zenBindingTitle: Binding<String> {
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

    var isAIAvailable: Bool {
        preferences.isPreferredAIServiceConfigured
    }
    
    var zenBindingSelection: Binding<NSRange?> {
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

    var zenTargetIndex: Int {
        if case .alternative(let i) = zenTarget { return i }
        return 0
    }

    var zenBindingAIResult: Binding<AIResult?> {
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

    var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : (selectedFolder == nil ? .gray : Color.blue)
    }

    var currentCategoryColor: Color {
        if let folderName = selectedFolder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .gray
        }
        return .gray
    }

    // Propiedad calculada para saber si el prompt está vacío
    var isContentEmpty: Bool {
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
    func mainScrollViewContent(geometry: GeometryProxy) -> some View {
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
                viewModel: viewModel,
                currentCategoryColor: currentCategoryColor
            )
            .frame(minHeight: geometry.size.height * 0.98)
            
            Spacer().frame(height: 20)

            // SECTION 2: ADVANCED FIELDS
            if preferences.showAdvancedFields || !negativePrompt.isEmpty || alternatives.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                PromptAdvancedFieldsView(
                    negativePrompt: vmBinding(\.negativePrompt),
                    alternatives: vmBinding(\.alternatives),
                    alternativeDescriptions: vmBinding(\.alternativeDescriptions),
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

                // Contextual Awareness (App Association)
                PromptAppTargetsView(
                    targetAppBundleIDs: vmBinding(\.targetAppBundleIDs),
                    themeColor: themeColor,
                    currentCategoryColor: currentCategoryColor,
                    preferences: preferences,
                    promptService: promptService
                )

                // Prompt Results (Extracted Component)
                PromptResultsSectionView(
                    showcaseImages: vmBinding(\.showcaseImages),
                    mediaState: $mediaState,
                    branchMessage: vmBinding(\.branchMessage),
                    preferences: preferences,
                    themeColor: themeColor
                )
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    func alternativeRow(index: Int) -> some View {
        SecondaryEditorCard(
            title: "\("alternative".localized(for: preferences.language)) #\(index + 1)",
            subtitleBinding: Binding(
                get: { alternativeDescriptions.indices.contains(index) ? alternativeDescriptions[index] : "" },
                set: { newValue in
                    guard alternativeDescriptions.indices.contains(index) else { return }
                    alternativeDescriptions[index] = String(
                        newValue
                            .replacingOccurrences(of: "\n", with: " ")
                            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                            .prefix(120)
                    )
                }
            ),
            subtitlePlaceholder: "alternative_desc_placeholder".localized(for: preferences.language),
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
                        }
                        HapticService.shared.playLight()
                        showTransientBranchMessage("Content swapped!")
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
                        }
                        HapticService.shared.playLight()
                        showTransientBranchMessage("Merged into main!")
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
                        if alternativeDescriptions.indices.contains(index) {
                            _ = alternativeDescriptions.remove(at: index)
                        }
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

    var fullScreenImageSheetItem: Binding<IdentifiableData?> {
        Binding(
            get: { mediaState.fullScreenImageData.map { IdentifiableData(value: $0) } },
            set: { mediaState.fullScreenImageData = $0?.value }
        )
    }

    private struct DraftState: Equatable {
        let title: String
        let content: String
        let negativePrompt: String
        let alternatives: [String]
        let alternativeDescriptions: [String]
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
            alternativeDescriptions: alternativeDescriptions,
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

    var hasUnsavedChanges: Bool {
        if let existingPrompt = originalPrompt ?? prompt {
            var existingAlts = existingPrompt.alternatives
            if existingAlts.isEmpty, let legacy = existingPrompt.alternativePrompt, !legacy.isEmpty {
                existingAlts = [legacy]
            }
            let existingAltDescriptions = normalizedAlternativeDescriptions(from: existingPrompt, for: existingAlts)
            
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
                   existingAltDescriptions != alternativeDescriptions ||
                   existingPrompt.tags != tags ||
                   existingPrompt.targetAppBundleIDs != targetAppBundleIDs ||
                   existingPrompt.customShortcut != customShortcut
        } else {
            // Para un prompt nuevo, solo consideramos que hay cambios sin guardar
            // si el usuario realmente ha escrito un título o contenido explícito.
            let isTitleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isContentTextEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isDescEmpty = promptDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isNegEmpty = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasAlts = !alternatives.isEmpty && alternatives.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            
            return !isTitleEmpty || !isContentTextEmpty || !isDescEmpty || !isNegEmpty || hasAlts || !showcaseImages.isEmpty
        }
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
        .magicGlobalDropOverlay(isProcessing: viewModel.isMagicImageProcessing) { data in
            viewModel.extractMagicPrompt(from: data, preferences: preferences)
        }
        .sheet(item: fullScreenImageSheetItem) { item in
            FullScreenImageView(imageData: item.value)
                .onDisappear {
                    MenuBarManager.shared.fixTransientState()
                }
        }
        .overlay { overlays }
                                .sheet(item: $diffComparison) { comparison in
                    DiffView(
                        text1: comparison.text1,
                        text2: comparison.text2,
                        title1: comparison.title1,
                        title2: comparison.title2
                    )
                }
                .onChange(of: showingPremiumFor) { _, newValue in
                    if newValue != nil {
                        PremiumUpsellWindowManager.shared.show(featureName: "Promtier Pro")
                        showingPremiumFor = nil
                    }
                }
                .onChange(of: showSnippets) { _, newValue in
                    if newValue && !preferences.isPremiumActive {
                        showSnippets = false
                        PremiumUpsellWindowManager.shared.show(featureName: "Promtier Pro")
                    }
                }
                .onChange(of: showVariables) { _, newValue in
                    if newValue && !preferences.isPremiumActive {
                        showVariables = false
                        PremiumUpsellWindowManager.shared.show(featureName: "Promtier Pro")
                    }
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
        .onChange(of: viewModel.title) { _, newValue in
            titleHoister.setExternal(newValue)
        }
        .onChange(of: viewModel.content) { _, newValue in
            contentHoister.setExternal(newValue)
        }
        .onChange(of: viewModel.promptDescription) { _, newValue in
            promptDescriptionHoister.setExternal(newValue)
        }
        .onAppear {
            setupOnAppear()
            setupKeyboardMonitor()
        }
        .onDisappear {
            keyboardCoordinator.stop()
            // Cancelar auto-guardado pendiente al salir de la vista
            MenuBarManager.shared.isModalActive = false
        }
        .onChange(of: draftState) { _, _ in
            saveCurrentDraft()
        }
        .onChange(of: alternatives) { _, _ in
            syncAlternativeDescriptionsWithAlternatives()
        }
        .onChange(of: showcaseImages) { _, images in
            mediaState.clampSelection(for: images)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FloatingZenDraftUpdated"))) { _ in
            DispatchQueue.main.async {
                self.setupOnAppear()
            }
        }
    }




    @ViewBuilder
    var overlays: some View {
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
            creationOptionsOverlayLayer

            if let msg = branchMessage {
                NewPromptBranchMessageOverlay(
                    message: msg,
                    language: preferences.language,
                    onSettings: {
                        viewModel.showingAIPrefs = true
                    }
                )
            }
        }
    .sheet(isPresented: $viewModel.showingAIPrefs) {
        PreferencesView(onClose: {
            viewModel.showingAIPrefs = false
        })
        .frame(width: 850, height: 600)
    }
    }

    var snippetsOverlayLayer: some View {        ZStack {
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

    var variablesOverlayLayer: some View {
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

    var magicOptionsOverlayLayer: some View {
        NewPromptMagicOptionsOverlay(
            showingMagicOptions: vmBinding(\.showingMagicOptions),
            magicTarget: vmBinding(\.magicTarget),
            magicCommand: vmBinding(\.magicCommand),
            executeAction: { executeMagicWithCommand() }
        )
    }

    var creationOptionsOverlayLayer: some View {
        NewPromptCreationOptionsOverlay(
            showingCreationOptions: vmBinding(\.showingCreationOptions),
            executeAction: { keepContent in executeAutocomplete(keepContent: keepContent) }
        )
    }












    var isTextInputFocused: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView || NSApp.keyWindow?.firstResponder is NSTextField
    }

    func normalizedAlternatives(from source: Prompt) -> [String] {
        var normalized = source.alternatives
        if normalized.isEmpty, let legacy = source.alternativePrompt, !legacy.isEmpty {
            normalized = [legacy]
        }
        return normalized
    }

    func normalizedAlternativeDescriptions(from source: Prompt, for alternatives: [String]) -> [String] {
        var normalized = source.alternativeDescriptions
        if normalized.count < alternatives.count {
            normalized.append(contentsOf: Array(repeating: "", count: alternatives.count - normalized.count))
        } else if normalized.count > alternatives.count {
            normalized = Array(normalized.prefix(alternatives.count))
        }
        return normalized
    }




    // MARK: - Image Import Helpers


    var imageSlotsFullMessage: String {
        PromptMediaImportPipeline.localizedMessage(for: .slotsFull, language: preferences.language)
    }



    var backgroundView: some View {
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

    var normalizedPromptDescription: String? {
        promptDescription.isEmpty ? nil : promptDescription
    }

    var normalizedNegativePrompt: String? {
        negativePrompt.isEmpty ? nil : negativePrompt
    }

    func hasBasicPromptChanges(comparedTo existingPrompt: Prompt, newNegativePrompt: String?) -> Bool {
        existingPrompt.title != title ||
        existingPrompt.content != content ||
        existingPrompt.promptDescription != normalizedPromptDescription ||
        existingPrompt.folder != selectedFolder ||
        existingPrompt.isFavorite != isFavorite ||
        existingPrompt.icon != selectedIcon ||
        existingPrompt.showcaseImages != showcaseImages ||
        existingPrompt.negativePrompt != newNegativePrompt ||
        existingPrompt.alternatives != alternatives ||
        existingPrompt.alternativeDescriptions != alternativeDescriptions ||
        existingPrompt.targetAppBundleIDs != targetAppBundleIDs ||
        existingPrompt.customShortcut != customShortcut
    }

    func appendVersionSnapshotIfNeeded(to updatedPrompt: inout Prompt, from existingPrompt: Prompt, newNegativePrompt: String?) {
        guard preferences.isPremiumActive else { return }

        let coreChanges = existingPrompt.title != title ||
        existingPrompt.content != content ||
        existingPrompt.negativePrompt != newNegativePrompt ||
        existingPrompt.alternatives != alternatives ||
        existingPrompt.alternativeDescriptions != alternativeDescriptions

        guard coreChanges else { return }

        let snapshot = PromptSnapshot(
            title: title,
            content: content,
            negativePrompt: newNegativePrompt,
            alternatives: alternatives,
            alternativeDescriptions: alternativeDescriptions,
            timestamp: Date()
        )
        var history = existingPrompt.versionHistory
        history.insert(snapshot, at: 0)
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        updatedPrompt.versionHistory = history
    }

    func applyEditableFields(to updatedPrompt: inout Prompt, newNegativePrompt: String?) {
        updatedPrompt.title = title
        updatedPrompt.content = content
        updatedPrompt.promptDescription = normalizedPromptDescription
        updatedPrompt.folder = selectedFolder
        updatedPrompt.isFavorite = isFavorite
        updatedPrompt.icon = selectedIcon
        updatedPrompt.showcaseImages = showcaseImages
        updatedPrompt.tags = tags
        updatedPrompt.negativePrompt = newNegativePrompt
        updatedPrompt.alternatives = alternatives
        updatedPrompt.alternativeDescriptions = alternativeDescriptions
        updatedPrompt.targetAppBundleIDs = targetAppBundleIDs
        updatedPrompt.customShortcut = customShortcut
        updatedPrompt.modifiedAt = Date()
    }





    // MARK: - AI Magic Features (ViewModel-backed)







    var snippetOverlay: some View {
        VStack {
            Spacer()
            if preferences.isPremiumActive {
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

    var variablesOverlay: some View {
        VStack {
            Spacer()
            if preferences.isPremiumActive {
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
