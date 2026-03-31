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
    var prompt: Prompt?
    var onClose: () -> Void

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager

    @State private var title = ""
    @State private var content = ""
    @State private var negativePrompt = ""
    @State private var alternatives: [String] = []
    @State private var promptDescription = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var selectedIcon: String?
    @State private var showcaseImages: [Data] = []
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
    @State private var isDragging = false
    @State private var draggedImageIndex: Int? = nil
    @State private var showingFullScreenImage: Data? = nil

    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var showingTagEditor: Bool = false
    @State private var showingCloseAlert: Bool = false
    @State private var selectedImageIndex: Int = 0 // Track which image is selected for spacebar preview
    
    // Magic Options State
    @State private var showingMagicOptions: Bool = false
    @State private var magicCommand: String = ""
    @State private var magicTarget: MagicTarget = .content

    enum MagicTarget: String, CaseIterable, Identifiable {
        case title = "Título"
        case description = "Descripción"
        case content = "Prompt"
        var id: String { self.rawValue }
    }
    
    @State private var showingAlternativeGenerator: Bool = false

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
    @State private var showingPremiumFor: String? = nil // Determina qué feature premium mostrar en el upsell

    @State private var showNegativeField: Bool = false
    @State private var showAlternativeField: Bool = false
    @State private var customShortcut: String? = nil

    @State private var focusNegative: Bool = false
    @State private var focusAlternative: Bool = false
    @State private var targetAppBundleIDs: [String] = []
    @State private var showingShortcutHelp: Bool = false
    @State private var showingSmartHelp: Bool = false
    @State private var localMonitor: Any? = nil
    struct DiffComparison: Identifiable {
        let id = UUID()
        let text1: String
        let text2: String
        let title1: String
        let title2: String
    }

    @State private var diffComparison: DiffComparison? = nil
    @State private var branchMessage: String? = nil
    @State private var showingAppPicker = false

    @State private var cancellables = Set<AnyCancellable>()
    @State private var isAutocompleting: Bool = false
    @State private var isCategorizing: Bool = false
    @State private var aiTask: Task<Void, Never>? = nil

    // Identificador para rastrear cambios y guardar borradores
    @State private var originalPrompt: Prompt? = nil
    @State private var isDraftRestored = false
    @State private var autoSaveWorkItem: DispatchWorkItem? = nil
    /// Guard que impide que un auto-guardado pendiente se ejecute después de descartar
    @State private var isDiscarding: Bool = false
    
    // Estados de Hover para la cabecera
    @State private var isHoveringCancel = false
    @State private var isHoveringHistory = false
    @State private var isHoveringFavorite = false
    @State private var isHoveringZen = false
    @State private var isHoveringPin = false
    @State private var isHoveringBranch = false
    @State private var isHoveringSave = false
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
    
    // Builds the language instruction to inject into AI prompts
    private var aiLanguageInstruction: String {
        switch preferences.aiResponseLanguage {
        case "es": return "IMPORTANT: Respond ENTIRELY in Spanish. Do not use any other language."
        case "en": return "IMPORTANT: Respond ENTIRELY in English. Do not use any other language."
        default:   return ""  // auto: let the model detect from input
        }
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
        title.trimmingCharacters(in: .whitespaces).isEmpty &&
        content.trimmingCharacters(in: .whitespaces).isEmpty &&
        negativePrompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        alternatives.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        promptDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        showcaseImages.isEmpty
    }

    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
        self._originalPrompt = State(initialValue: prompt)
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
                title: $title,
                content: $content,
                promptDescription: $promptDescription,
                isFavorite: $isFavorite,
                selectedFolder: $selectedFolder,
                selectedIcon: $selectedIcon,
                fallbackIconName: selectedFolder.flatMap { PredefinedCategory.fromString($0)?.icon } ?? "doc.text.fill",
                showingIconPicker: $showingIconPicker,
                showingZenEditor: $showingZenEditor,
                zenTarget: $zenTarget,
                showingPremiumFor: $showingPremiumFor,
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
                branchMessage: $branchMessage,
                editorID: "main",
                currentCategoryColor: currentCategoryColor
            )
            .frame(minHeight: geometry.size.height * 0.98)
            
            Spacer().frame(height: 20)

            // SECTION 2: ADVANCED FIELDS
            if preferences.showAdvancedFields || !negativePrompt.isEmpty || alternatives.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 24) {
                        // 2.1: NEGATIVE PROMPT
                        SecondaryEditorCard(
                            title: "negative_prompt".localized(for: preferences.language),
                            placeholder: "negative_prompt_placeholder".localized(for: preferences.language),
                            text: $negativePrompt,
                            icon: "hand.raised.fill",
                            color: .red,
                            focusRequest: $focusNegative,
                            onZenMode: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    zenTarget = .negative
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
                                    // Action: Swap
                                    Button(action: {
                                        withAnimation {
                                            let temp = content
                                            content = negativePrompt
                                            negativePrompt = temp
                                            branchMessage = "Content swapped!"
                                        }
                                        HapticService.shared.playLight()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { branchMessage = nil } }
                                    }) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                    .help("Swap with main prompt")

                                    // Action: Merge
                                    Button(action: {
                                        withAnimation {
                                            if !content.isEmpty { content += "\n\n---\n\n" }
                                            content += negativePrompt
                                            negativePrompt = ""
                                            branchMessage = "Merged into main!"
                                        }
                                        HapticService.shared.playLight()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { branchMessage = nil } }
                                    }) {
                                        Image(systemName: "arrow.down.to.line.compact")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                    .help("Merge into main prompt")

                                    // Action: Compare
                                    Button(action: {
                                        diffComparison = DiffComparison(
                                            text1: content,
                                            text2: negativePrompt,
                                            title1: "main_content".localized(for: preferences.language),
                                            title2: "negative_prompt".localized(for: preferences.language)
                                        )
                                    }) {
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

                        // 2.2: ALTERNATIVE PROMPTS
                        VStack(alignment: .leading, spacing: 16) {
                            if !alternatives.isEmpty {
                                VStack(spacing: 16) {
                                    ForEach(Array(alternatives.enumerated()), id: \.offset) { index, _ in
                                        alternativeRow(index: index)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }

                            if alternatives.count < 10 {
                                Button(action: {
                                    if preferences.isPremiumActive && isAIAvailable {
                                        showingAlternativeGenerator = true
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            alternatives.append("")
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("add_alternative".localized(for: preferences.language))
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(themeColor)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(
                                        ZStack {
                                            // Efecto de luz (brillo difuso)
                                            if preferences.isHaloEffectEnabled {
                                                currentCategoryColor.opacity(0.15)
                                                    .blur(radius: 12)
                                            }

                                            // Fondo sólido estilizado
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(themeColor.opacity(0.15))
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themeColor.opacity(0.2), lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .id("alternatives_section")
                    }
                }
            }

            Spacer().frame(height: 20)

            // SECTION 3: UTILITIES
            VStack(alignment: .leading, spacing: 20) {
                // Atajo Individual (Movido aquí para mayor visibilidad)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(currentCategoryColor)
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
                                ReusableShortcutRecorderView(title: "", shortcutString: $customShortcut)
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(currentCategoryColor)
                        Text("smart_recommendation".localized(for: preferences.language).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)
                        
                        Button(action: { showingSmartHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingSmartHelp) {
                            helpPopover(title: "smart_recommendation_help", content: "smart_recommendation_help_desc")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        if targetAppBundleIDs.isEmpty {
                            Text("no_apps_assigned".localized(for: preferences.language))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(targetAppBundleIDs, id: \.self) { bundleID in
                                    HStack(spacing: 6) {
                                        if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path {
                                            let icon = NSWorkspace.shared.icon(forFile: path)
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 16, height: 16)
                                        }

                                        Text(getAppName(bundleID))
                                            .font(.system(size: 12, weight: .medium))

                                        Button(action: {
                                            withAnimation {
                                                targetAppBundleIDs.removeAll { $0 == bundleID }
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        Button(action: { showingAppPicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("assign_app".localized(for: preferences.language))
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(themeColor.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
                                AppPickerPopover(
                                    runningApps: getRunningApps(),
                                    currentAppID: promptService.activeAppBundleID,
                                    titleKey: "smart_recommendation",
                                    onSelect: { bundleID in
                                        if !targetAppBundleIDs.contains(bundleID) {
                                            withAnimation {
                                                targetAppBundleIDs.append(bundleID)
                                            }
                                        }
                                        showingAppPicker = false
                                    },
                                    onBrowse: {
                                        showingAppPicker = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            selectApplication()
                                        }
                                    }
                                )
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

                // Prompt Results (Moved here per user request)
                imageGallery(width: geometry.size.width * 0.9)
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
            showingPremiumFor: $showingPremiumFor,
            originalPrompt: originalPrompt,
            prompt: prompt,
            branchMessage: $branchMessage,
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
            return !title.isEmpty || !content.isEmpty || !promptDescription.isEmpty ||
                   !negativePrompt.isEmpty || !alternatives.isEmpty || !showcaseImages.isEmpty ||
                   !tags.isEmpty || !targetAppBundleIDs.isEmpty || customShortcut != nil ||
                   isFavorite || selectedFolder != nil || selectedIcon != nil
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
        savePrompt(closeAfter: true, isAutoSave: false)
    }

    private func discardChanges() {
        // Cancelar inmediatamente cualquier auto-guardado pendiente para que no
        // se ejecute después de que el usuario haya elegido Descartar.
        isDiscarding = true
        autoSaveWorkItem?.cancel()
        autoSaveWorkItem = nil
        DraftService.shared.clearDraft()
        MenuBarManager.shared.isModalActive = false
        onClose()
    }

    var body: some View {
        GeometryReader { geometry in
            let targetWidth = geometry.size.width * 0.9

            VStack(spacing: 0) {
                header(width: targetWidth)

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
                .sheet(isPresented: $showingAlternativeGenerator) {
                    AlternativeGeneratorView(
                        originalPrompt: content,
                        onGenerate: { newAlternative in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                alternatives.append(newAlternative)
                            }
                            HapticService.shared.playSuccess()
                        }
                    )
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
            autoSaveWorkItem?.cancel()
            autoSaveWorkItem = nil
            MenuBarManager.shared.isModalActive = false
        }
        .onChange(of: draftState) { _, _ in
            saveCurrentDraft()
            debounceAutoSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FloatingZenDraftUpdated"))) { _ in
            DispatchQueue.main.async {
                self.setupOnAppear()
            }
        }
    }

    private func debounceAutoSave() {
        // Si el usuario ya descartó los cambios, no programar ningún guardado
        guard !isDiscarding else { return }
        
        autoSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [self] in
            // Doble verificación: asegurarse de que no se haya descartado
            // durante el tiempo de espera del debounce (2 s)
            guard !isDiscarding else { return }
            // Solo auto-guardar si estamos editando un prompt existente
            // Y no guardar si el prompt está vacío
            if originalPrompt != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty && !content.trimmingCharacters(in: .whitespaces).isEmpty {
                savePrompt(closeAfter: false, isAutoSave: true)
            }
        }
        autoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
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
            magicOptionsOverlayLayer

            if let msg = branchMessage {
                VStack {
                    Spacer()
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
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Instrucciones")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        
                                    TextField("Ej: Haz el texto más amigable...", text: $magicCommand, axis: .vertical)
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
            
                                HStack {
                                    Spacer()
                                    Button("Modificar") { executeMagicWithCommand() }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.large)
                                        .disabled(magicCommand.trimmingCharacters(in: .whitespaces).isEmpty)
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
                    }
                    return nil
                }
                if event.keyCode == 124 { // Right Arrow
                    DispatchQueue.main.async {
                        self.selectedImageIndex = min(self.showcaseImages.count - 1, self.selectedImageIndex + 1)
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

            // Cmd + V -> Paste Image globally
            if modifiers == .command && event.keyCode == 9 { // 'V' is keyCode 9
                let pb = NSPasteboard.general
                // Check if the primary item is an image
                if let types = pb.types, types.contains(where: { $0.rawValue.starts(with: "public.image") || $0 == .png || $0 == .tiff }) {
                    if let pbData = pb.data(forType: .png) ?? pb.data(forType: .tiff) ?? pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                        DispatchQueue.global(qos: .userInitiated).async {
                            if let optimizedData = ImageOptimizer.shared.optimize(imageData: pbData) {
                                DispatchQueue.main.async {
                                    if self.showcaseImages.count < 3 {
                                        self.showcaseImages.append(optimizedData)
                                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                    }
                                }
                            }
                        }
                        return nil // Consume event
                    } else if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                        DispatchQueue.global(qos: .userInitiated).async {
                            guard let tiffData = image.tiffRepresentation,
                                  let bitmap = NSBitmapImageRep(data: tiffData),
                                  let jpData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
                                  let optimizedData = ImageOptimizer.shared.optimize(imageData: jpData) else { return }
                            
                            DispatchQueue.main.async {
                                if self.showcaseImages.count < 3 {
                                    self.showcaseImages.append(optimizedData)
                                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                }
                            }
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

    // MARK: - Subviews

    private func header(width: CGFloat) -> some View {
        ZStack {
            // Botones laterales (Cancel y Acciones)
            HStack(alignment: .center) {
                Button(action: {
                    if hasUnsavedChanges {
                        showingCloseAlert = true
                    } else {
                        discardChanges()
                    }
                }) {
                    Text("cancel".localized(for: preferences.language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveringCancel ? currentCategoryColor.opacity(0.12) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCancel = $0 }
                .animation(.easeInOut(duration: 0.2), value: isHoveringCancel)

                Spacer()

                HStack(spacing: 12) {

                    if originalPrompt != nil && !originalPrompt!.versionHistory.isEmpty {
                        Button(action: {
                            if preferences.isPremiumActive {
                                showingVersionHistory = true
                            } else {
                                showingPremiumFor = "Version History"
                            }
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeColor)
                                .frame(width: 32, height: 32)
                                .background(themeColor.opacity(isHoveringHistory ? 0.25 : 0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringHistory = $0 }
                        .animation(.easeInOut(duration: 0.2), value: isHoveringHistory)
                        .help("Ver historial")
                        .transition(.opacity)
                    }


                    Button(action: {
                        // Force save current draft state
                        saveCurrentDraft()

                        // Extract title and content to floating manager
                        FloatingZenManager.shared.show(title: title, promptDescription: promptDescription, content: content, showcaseImages: showcaseImages, promptId: originalPrompt?.id ?? prompt?.id, isEditing: true)
                        // Close popover
                        MenuBarManager.shared.closePopover()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(themeColor.opacity(isHoveringZen ? 0.25 : 0.1)))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringZen = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringZen)
                    .help("Floating Zen Mode")

                    // Botón de fijar ventana (Pin)
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isPinned.toggle()
                            MenuBarManager.shared.isModalActive = isPinned
                        }
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isPinned ? .white : themeColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(
                                    isPinned
                                        ? themeColor
                                        : themeColor.opacity(isHoveringPin ? 0.25 : 0.1)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPin = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringPin)
                    .animation(.easeInOut(duration: 0.2), value: isPinned)
                    .help(isPinned ? "Desfijar ventana (Cmd+L)" : "Fijar ventana (Cmd+L)")
                    .keyboardShortcut("l", modifiers: .command)

                    if (originalPrompt ?? prompt) != nil {
                        Button(action: { branchPrompt() }) {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeColor)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(themeColor.opacity(isHoveringBranch ? 0.25 : 0.1)))
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringBranch = $0 }
                        .animation(.easeInOut(duration: 0.2), value: isHoveringBranch)
                        .help("create_branch".localized(for: preferences.language))
                    }

                    Button(action: { 
                        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            savePrompt() 
                        } else {
                            HapticService.shared.playError()
                            withAnimation {
                                self.branchMessage = "required_fields".localized(for: self.preferences.language)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation { if self.branchMessage == "required_fields".localized(for: self.preferences.language) { self.branchMessage = nil } }
                            }
                        }
                    }) {
                        Text(prompt != nil ? "save".localized(for: preferences.language) : "create".localized(for: preferences.language))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : (isHoveringSave ? currentCategoryColor.opacity(0.85) : (preferences.isHaloEffectEnabled ? currentCategoryColor : .blue)))
                                    .shadow(color: title.isEmpty || content.isEmpty ? .clear : (preferences.isHaloEffectEnabled ? (isHoveringSave ? currentCategoryColor.opacity(0.4) : currentCategoryColor.opacity(0.2)) : .clear), radius: isHoveringSave ? 8 : 4, y: isHoveringSave ? 4 : 2)
                            )
                            .scaleEffect(isHoveringSave ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringSave = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringSave)
                    .disabled(title.isEmpty || content.isEmpty)
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            .padding(.horizontal, 16)

            // Título central (Ajustado para estar siempre al centro real)
            VStack(spacing: 2) {
                Text(prompt != nil ? "edit_prompt".localized(for: preferences.language) : "new_prompt".localized(for: preferences.language))
                    .font(.system(size: 15, weight: .bold))
                Text(prompt != nil ? "update_details".localized(for: preferences.language) : "create_tool".localized(for: preferences.language))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .allowsHitTesting(false) // Dejar que los clics pasen a los botones si hubiera solapamiento
        }
        .frame(width: width)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

                private func imageGallery(width: CGFloat) -> some View {
                    let slotWidth = (width - 52) / 3
                    let slotHeight = slotWidth * 0.66
                    
                    return VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeColor)
                            Text("prompt_results".localized(for: preferences.language).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)

                            if showcaseImages.count < 3 {
                                Button(action: selectImages) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(themeColor)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .help("add_image".localized(for: preferences.language))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 0)

                        ScrollView(.horizontal, showsIndicators: false) {                HStack(spacing: 12) {
                    // Imágenes actuales
                    ForEach(0..<showcaseImages.count, id: \.self) { index in
                        ImageSlotView(
                            imageData: showcaseImages[index],
                            slotWidth: slotWidth,
                            slotHeight: slotHeight,
                            isSelected: selectedImageIndex == index,
                            onRemove: { 
                                showcaseImages.remove(at: index)
                                if selectedImageIndex >= showcaseImages.count {
                                    selectedImageIndex = max(0, showcaseImages.count - 1)
                                }
                            },
                            onPreview: { 
                                selectedImageIndex = index
                                showingFullScreenImage = showcaseImages[index] 
                            },
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                            onDragStart: { self.draggedImageIndex = index }
                        )
                    }

                    // Placeholders para completar hasta 3
                    ForEach(showcaseImages.count..<3, id: \.self) { index in
                        PlaceholderSlotView(
                            slotWidth: slotWidth,
                            slotHeight: slotHeight,
                            onSelect: selectImages,
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                            tintColor: Color(hex: promptService.folders.first(where: { $0.name == selectedFolder })?.displayColor ?? "#007AFF")
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12) // Añadido horizontal para evitar cortes al escalar
                .contentShape(Rectangle())
            }
            .onPasteCommand(of: [.image]) { providers in
                handleGalleryDrop(providers: providers)
            }
        }
        .padding(.top, 16)
    }

    private func handleGalleryDrop(providers: [NSItemProvider], at index: Int? = nil) {
        if let sourceIndex = draggedImageIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let item = showcaseImages.remove(at: sourceIndex)
                let targetIndex = min(index ?? showcaseImages.count, showcaseImages.count)
                showcaseImages.insert(item, at: targetIndex)
                HapticService.shared.playLight()
            }
            draggedImageIndex = nil
            return
        }

        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        DispatchQueue.global(qos: .userInitiated).async {
                            guard let tiffData = nsImage.tiffRepresentation,
                                  let bitmap = NSBitmapImageRep(data: tiffData),
                                  let baseData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return }
                            
                            let optimizedData = ImageOptimizer.shared.optimize(imageData: baseData)
                            
                            DispatchQueue.main.async {
                                if let data = optimizedData {
                                    self.insertImage(data, at: index)
                                }
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data {
                        // Optimize in background thread
                        let optimizedData = ImageOptimizer.shared.optimize(imageData: data)
                        
                        DispatchQueue.main.async {
                            if let data = optimizedData {
                                self.insertImage(data, at: index)
                            }
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        if url.isFileURL {
                            if let data = try? Data(contentsOf: url) {
                                // Optimize in background thread
                                let optimizedData = ImageOptimizer.shared.optimize(imageData: data)
                                
                                DispatchQueue.main.async {
                                    if let data = optimizedData {
                                        self.insertImage(data, at: index)
                                    }
                                }
                            }
                        } else {
                            // Descargar imagen de web URL (Chrome/Safari drag)
                            URLSession.shared.dataTask(with: url) { data, _, _ in
                                if let data = data {
                                    // Optimize in background thread
                                    let optimizedData = ImageOptimizer.shared.optimize(imageData: data)
                                    
                                    DispatchQueue.main.async {
                                        if let data = optimizedData {
                                            self.insertImage(data, at: index)
                                        }
                                    }
                                }
                            }.resume()
                        }
                    }
                }
            }
        }
    }

    private func insertImage(_ data: Data, at index: Int?) {
        if showcaseImages.count < 3 {
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
                    .animation(.easeInOut(duration: 1.2), value: selectedFolder)

                Circle()
                    .fill(currentCategoryColor.opacity(0.12))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: -250, y: 200)
            }

            // Brillo ambiental central que cambia con la categoría
            Circle()
                .fill(currentCategoryColor.opacity(0.05))
                .frame(width: 600, height: 600)
                .blur(radius: 120)
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: selectedFolder)
        }
    }

    private func savePrompt(closeAfter: Bool = true, isAutoSave: Bool = false) {
        if !isAutoSave {
            isSaving = true
        }

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
            if preferences.isPremiumActive && !isAutoSave {
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

            if isAutoSave {
                DispatchQueue.main.async { self.originalPrompt = new }
            }
        }

        if closeAfter {
            if preferences.isPremiumActive && preferences.visualEffectsEnabled && !isAutoSave {
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

    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        panel.begin { response in
            guard response == .OK else { return }
            
            let urls = panel.urls
            DispatchQueue.global(qos: .userInitiated).async {
                for url in urls {
                    // Cargar y optimizar en background
                    if let data = try? Data(contentsOf: url),
                       let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        
                        DispatchQueue.main.async {
                            if self.showcaseImages.count < 3 {
                                self.showcaseImages.append(optimizedData)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI Magic Features

    private func autocompletePromptContent() {
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            // Animación de error sutil si ambos están vacíos
            HapticService.shared.playError()
            return
        }
        
        if !trimmedTitle.isEmpty && !trimmedContent.isEmpty {
            // Si ya está lleno, preguntamos qué quiere hacer y qué modificar
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingMagicOptions = true
            }
            return
        }
        
        isAutocompleting = true
        HapticService.shared.playImpact()
        
        // ✨ Mostrar aviso de que se está ejecutando la magia
        withAnimation {
            branchMessage = "ai_thinking".localized(for: preferences.language)
        }
        
        let systemPrompt: String
        let currentTitle = trimmedTitle.isEmpty ? "No title provided" : trimmedTitle
        let currentContent = trimmedContent.isEmpty ? "No content provided" : trimmedContent
        
        let isContentProvided = !trimmedContent.isEmpty
        let isTitleProvided = !trimmedTitle.isEmpty
        
        let titleInstruction = isTitleProvided
            ? "The title is already provided. DO NOT modify it in any way. Return it EXACTLY as it is."
            : "If the title is empty or generic, generate a catchy, short title (max 1 line)."

        let contentInstruction = isContentProvided
            ? "CRITICAL: The content is already provided. DO NOT modify it in any way. Return it EXACTLY as it is."
            : "Generate the main prompt content. It must be high-quality and detailed. Maintain EXISTING variables {{...}} but do NOT add new ones unless essential."

        systemPrompt = """
        You are an expert prompt engineer. Your goal is to create or improve an AI prompt based on the user's input.
        
        INPUTS:
        - Title: \(currentTitle)
        - Content: \(currentContent)
        
        INSTRUCTIONS:
        1. TITLE: \(titleInstruction)
        2. DESCRIPTION: Generate a concise description of what this prompt does (max 2 lines).
        3. CONTENT: \(contentInstruction)
        
        CRITICAL LANGUAGE RULE:
        - Detect the PRIMARY language of the user's input (title and content).
        - You MUST respond ENTIRELY in that SAME language. Every word of your response — title, description, content, variable names — must be in the input's language.
        - If input is Spanish → respond in Spanish. If English → respond in English. Never mix languages.
        
        RESPONSE FORMAT:
        Respond ONLY with the following format, using the pipe symbol (|) as separator:
        GeneratedTitle|GeneratedDescription|GeneratedContent
        
        DO NOT include any other text, labels, or explanations. Just the three parts separated by |.
        """
        
        Task {
            do {
                let fullResponse: String
                if preferences.preferredAIService == .openai {
                    fullResponse = try await OpenAIService.shared.generate(prompt: systemPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
                } else {
                    fullResponse = try await GeminiService.shared.generate(prompt: systemPrompt, model: preferences.geminiDefaultModel)
                }
                
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    HapticService.shared.playSuccess()
                    
                    if !fullResponse.isEmpty {
                        let parts = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
                        if parts.count >= 3 {
                            withAnimation(.spring()) {
                                self.title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.promptDescription = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.content = parts.dropFirst(2).joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
            // 🪄 Auto-Categorizar automáticamente después de generar el contenido
                            // Solo si NO hay una categoría ya seleccionada por el usuario
                            if self.selectedFolder == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.autoCategorizePrompt()
                                }
                            }
                        } else if !fullResponse.contains("|") {
                            // Fallback if AI didn't follow format strictly but gave content
                            withAnimation(.spring()) {
                                self.content = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    print("❌ Autocomplete Error: \(error.localizedDescription)")
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }

        private func executeMagicWithCommand() {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingMagicOptions = false
            }
    
            guard preferences.isPremiumActive else {            showingPremiumFor = "ai_magic"
            return
        }
        
        isAutocompleting = true
        HapticService.shared.playImpact()
        
        withAnimation {
            branchMessage = "ai_thinking".localized(for: preferences.language)
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = promptDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let command = magicCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var targetContext = ""
        var systemInstruction = ""
        
        switch magicTarget {
        case .title:
            targetContext = "Current Title: \(trimmedTitle)"
            systemInstruction = "Modify ONLY the title based on this instruction: '\(command)'. Maintain the language. Respond ONLY with the new title."
        case .description:
            targetContext = "Current Description: \(trimmedDescription.isEmpty ? "(None)" : trimmedDescription)"
            systemInstruction = "Modify ONLY the description based on this instruction: '\(command)'. Maintain the language. Respond ONLY with the new description."
        case .content:
            targetContext = "Current Content: \(trimmedContent)"
            systemInstruction = "Modify ONLY the prompt content based on this instruction: '\(command)'. Maintain ANY variables {{...}} exactly as they are. Maintain the language. Respond ONLY with the newly modified content text."
        }
        
        let systemPrompt = """
        You are an expert prompt engineer. Your goal is to modify a specific part of an AI prompt.
        
        \(targetContext)
        
        INSTRUCTION:
        \(systemInstruction)
        
        CRITICAL RULE:
        - Respond ONLY with the final requested text.
        - Do NOT add quotes, labels, or conversational filler like "Here is the modified text".
        """
        
        Task {
            do {
                let fullResponse: String
                if preferences.preferredAIService == .openai {
                    fullResponse = try await OpenAIService.shared.generate(prompt: systemPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
                } else {
                    fullResponse = try await GeminiService.shared.generate(prompt: systemPrompt, model: preferences.geminiDefaultModel)
                }
                
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    HapticService.shared.playSuccess()
                    
                    let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !result.isEmpty {
                        withAnimation(.spring()) {
                            switch magicTarget {
                            case .title:
                                self.title = result
                            case .description:
                                self.promptDescription = result
                            case .content:
                                self.content = result
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    print("❌ Magic Command Error: \(error.localizedDescription)")
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }

    private func autoCategorizePrompt() {
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            HapticService.shared.playError()
            return
        }
        
        // Si ya hay categoría seleccionada, solo buscar el icono
        let skipCategory = (selectedFolder != nil)
        
        isCategorizing = true
        HapticService.shared.playImpact()
        
        let folderNames = promptService.folders.map { $0.name }.joined(separator: ", ")
        
        // Construir lista de iconos válidos (solo un subconjunto representativo para no exceder tokens)
        let validIcons = [
            "brain.fill", "sparkles", "bolt.fill", "lightbulb.fill", "cpu.fill", "network", "wand.and.stars", "atom",
            "terminal.fill", "chevron.left.forwardslash.chevron.right", "curlybraces", "command.circle.fill",
            "gearshape.fill", "wrench.fill", "hammer.fill", "puzzlepiece.fill", "shippingbox.fill",
            "doc.text.fill", "pencil.and.outline", "text.quote", "book.closed.fill", "square.and.pencil",
            "note.text", "doc.richtext.fill", "list.bullet.indent", "character.bubble.fill",
            "chart.line.uptrend.xyaxis", "chart.bar.fill", "target", "briefcase.fill", "dollarsign.circle.fill",
            "tag.fill", "bookmark.fill", "link",
            "bubble.left.and.bubble.right.fill", "paperplane.fill", "megaphone.fill", "person.fill",
            "envelope.fill", "heart.fill", "message.fill",
            "photo.fill", "camera.fill", "paintpalette.fill", "film.fill", "mic.fill", "headphones",
            "video.fill", "scissors", "eye.fill", "music.note", "play.circle.fill",
            "star.fill", "flame.fill", "flag.fill", "bell.fill", "lock.fill", "key.fill",
            "calendar", "map.fill", "gift.fill", "gamecontroller.fill", "trophy.fill",
            "globe", "leaf.fill", "house.fill", "graduationcap.fill",
            "sun.max.fill", "moon.fill", "cloud.fill"
        ]
        let iconListString = validIcons.joined(separator: ", ")
        
        let categoryInstruction = skipCategory
            ? "The category is already set. Do NOT return a category. Respond ONLY with the icon name."
            : "Select the best category from this list: [\(folderNames)]."
        
        let formatInstruction = skipCategory
            ? "Respond ONLY with the SF Symbol name (e.g. terminal.fill). Nothing else."
            : "Format your response EXACTLY as: CategoryName|SymbolName\nRespond ONLY with this format, nothing else."
        
        let systemPrompt = """
        Based on the title '\(title)' and content '\(content)', \(categoryInstruction)
        Also suggest the most appropriate SF Symbol icon from ONLY this exact list: [\(iconListString)].
        You MUST choose from this list. Do NOT invent icon names.
        \(formatInstruction)
        """
        
        Task {
            do {
                let fullResponse: String
                if preferences.preferredAIService == .openai {
                    fullResponse = try await OpenAIService.shared.generate(prompt: systemPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
                } else {
                    fullResponse = try await GeminiService.shared.generate(prompt: systemPrompt, model: preferences.geminiDefaultModel)
                }
                
                await MainActor.run {
                    self.isCategorizing = false
                    HapticService.shared.playSuccess()
                    let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if skipCategory {
                        // Solo icono
                        let iconName = result.trimmingCharacters(in: .whitespacesAndNewlines)
                        if IconPickerView.allIconNames.contains(iconName) {
                            withAnimation(.spring()) { self.selectedIcon = iconName }
                        }
                    } else {
                        // Categoría|Icono
                        let parts = result.components(separatedBy: "|")
                        if parts.count == 2 {
                            let iconName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            withAnimation(.spring()) {
                                self.selectedFolder = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                if IconPickerView.allIconNames.contains(iconName) {
                                    self.selectedIcon = iconName
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCategorizing = false
                    print("❌ Categorization Error: \(error.localizedDescription)")
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }

    private func userFacingAIErrorToast(for error: Error) -> String {
        let nsError = error as NSError

        let baseKey: String = {
            if let openAIError = error as? OpenAIAPIError {
                switch openAIError.kind {
                case .invalidAPIKey: return "ai_error_invalid_api_key"
                case .modelNotFound: return "ai_error_model_not_found"
                case .rateLimited: return "ai_error_rate_limited"
                case .serverBusy: return "ai_error_server_busy"
                case .badRequest: return "ai_error_bad_request"
                case .emptyResponse: return "ai_error_empty_response"
                case .unknown: return "ai_error_unknown"
                }
            }

            if nsError.domain == NSURLErrorDomain {
                return "ai_error_network"
            }

            if nsError.domain == "GeminiAPI" {
                switch nsError.code {
                case 400: return "ai_error_bad_request"
                case 401, 403: return "ai_error_invalid_api_key"
                case 404: return "ai_error_model_not_found"
                case 429: return "ai_error_rate_limited"
                case 500, 502, 503, 504: return "ai_error_server_busy"
                default: return "ai_error_unknown"
                }
            }

            let lower = nsError.localizedDescription.lowercased()
            if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
                return "ai_error_model_not_found"
            }
            if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("429") {
                return "ai_error_rate_limited"
            }
            if lower.contains("invalid api key") || (lower.contains("api key") && lower.contains("invalid")) || lower.contains("401") {
                return "ai_error_invalid_api_key"
            }
            if lower.contains("overloaded") || lower.contains("server busy") || lower.contains("503") {
                return "ai_error_server_busy"
            }

            return "ai_error_unknown"
        }()

        let base = baseKey.localized(for: preferences.language)
        let detail = compactErrorDetail(from: error)
        if detail.isEmpty {
            return "❌ \(base)"
        }
        // Mensaje compacto: cabecera corta + primera línea del detalle (si existe)
        if let firstLine = detail.split(separator: ".").first, !firstLine.isEmpty {
            return "❌ \(base): \(firstLine.trimmingCharacters(in: .whitespaces))"
        }
        return "❌ \(base)"
    }

    private func compactErrorDetail(from error: Error) -> String {
        let raw: String = {
            if let openAIError = error as? OpenAIAPIError {
                return openAIError.message
            }
            return (error as NSError).localizedDescription
        }()

        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return "" }
        if cleaned.count <= 180 { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return String(cleaned[..<idx]) + "…"
    }

    // MARK: - App Association Helpers

    private func getRunningApps() -> [RunningApp] {
        return NSWorkspace.shared.getRelevantRunningApps()
    }

    private func getAppName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application, .aliasFile]
        panel.allowsMultipleSelection = true
        panel.message = "select_app_title".localized(for: preferences.language)

        // Nivel de panel modal para que NO salga por detrás de la ventana de NewPromptView
        panel.level = .modalPanel

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundleID = Bundle(url: url)?.bundleIdentifier {
                    if !targetAppBundleIDs.contains(bundleID) {
                        withAnimation {
                            targetAppBundleIDs.append(bundleID)
                        }
                    }
                } else {
                    // Intento manual vía plist si Bundle falla (apps externas raras)
                    let infoPath = url.appendingPathComponent("Contents/Info.plist")
                    if let infoDict = NSDictionary(contentsOf: infoPath),
                       let bundleID = infoDict["CFBundleIdentifier"] as? String {
                        if !targetAppBundleIDs.contains(bundleID) {
                            withAnimation {
                                targetAppBundleIDs.append(bundleID)
                            }
                        }
                    }
                }
            }
        }
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

struct EditorCard: View {
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

    let currentCategoryColor: Color
    
    var isAutocompleting: Bool = false
    var isCategorizing: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil
    var onMagicCategorize: (() -> Void)? = nil

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : .blue
    }

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
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
        self.currentCategoryColor = currentCategoryColor
    }

    private var isAIAvailable: Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }
    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var isMagicPulsing = false
    @State private var isMagicHovered = false
    @State private var magicRotationPhase: Double = 0
    @State private var cancellables = Set<AnyCancellable>()
    @State private var plainTextContent: String = ""
    @State private var aiTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: { showingIconPicker.toggle() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentCategoryColor.opacity(0.1))
                                .frame(width: 42, height: 42)

                            Image(systemName: selectedIcon ?? fallbackIconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(currentCategoryColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Change icon")
                    .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                        IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 22 * preferences.fontSize.scale, weight: .bold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // ✨ Botón Mágico: Autocompletar Título
                            if editorID == "main" {
                                Button(action: { 
                                    withAnimation { isMagicPulsing = false }
                                    onMagicAutocomplete?() 
                                }) {
                                    HStack(spacing: 4) {
                                        if isAutocompleting {
                                            ProgressView().controlSize(.small).scaleEffect(0.6)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        Text("MAGIC")
                                            .font(.system(size: 10.5, weight: .heavy))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22), currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22)], 
                                                startPoint: .leading, 
                                                endPoint: .trailing
                                            ))
                                            .opacity(isMagicPulsing ? 0.5 : 1.0)
                                            .shadow(color: currentCategoryColor.opacity(isMagicPulsing ? 0.7 : (isMagicHovered ? 0.6 : 0)), radius: isMagicPulsing ? 8 : (isMagicHovered ? 14 : 0))
                                    )
                                    .foregroundColor(isMagicHovered ? currentCategoryColor : currentCategoryColor.opacity(0.9))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [currentCategoryColor, currentCategoryColor.opacity(0.7), currentCategoryColor.opacity(0.4), currentCategoryColor.opacity(0.8), currentCategoryColor, currentCategoryColor.opacity(0.7), currentCategoryColor.opacity(0.4), currentCategoryColor.opacity(0.8)],
                                                    startPoint: UnitPoint(x: (magicRotationPhase / 360.0) - 1.0, y: 0),
                                                    endPoint: UnitPoint(x: (magicRotationPhase / 360.0), y: 1)
                                                ),
                                                lineWidth: isMagicPulsing ? 1.5 : (isMagicHovered ? 1.2 : 0.8)
                                            )
                                            .opacity(isMagicPulsing ? 0.8 : (isMagicHovered ? 1.0 : 0.5))
                                    )
                                    .scaleEffect(isMagicHovered ? 1.02 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                                        magicRotationPhase = 360
                                    }
                                }
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isMagicHovered = hovering
                                    }
                                }
                                .animation(
                                    isMagicPulsing 
                                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) 
                                        : .spring(response: 0.3, dampingFraction: 0.7), 
                                    value: isMagicPulsing
                                )
                                .help("Autocomplete content based on title (Cmd+J)")
                                .padding(.top, 2)
                            }
                        }

                        TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13 * preferences.fontSize.scale, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                            .frame(minHeight: 28, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } // Cierre de la cabecera (VStack en 1695)

            // ✅ Editor Principal con Herramientas Inteligentes (Sidebar Layout)
            HStack(alignment: .top, spacing: 0) {
                // El Editor
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
                    fontSize: 16 * preferences.fontSize.scale,
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
                        withAnimation(.spring()) {
                            isMagicPulsing = true
                        }
                        // Auto-dismiss pulse after 7 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                            withAnimation(.easeInOut) {
                                isMagicPulsing = false
                            }
                        }
                    }
                )
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .padding(.trailing, 5) // Espacio sutil de 5px
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)

                // Barra de Herramientas Lateral
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
                .padding(.vertical, 8)
                .padding(.trailing, 4) // Ajustado para dar más espacio al texto
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isTyping ? 2 : 1.5)
                            .shadow(color: preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .padding(.top, 14) // Espacio EXTERNO entre descripción y caja del editor
            .animation(.easeInOut(duration: 0.3), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(isTyping ? .spring(response: 0.35, dampingFraction: 0.7) : .easeOut(duration: 1.5), value: isTyping)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorFocused = true
                }
            }

            // ✅ Selector de Categoría (Restaurado aquí)
            HStack(spacing: 8) {
                CategoryPillPicker(selectedCategory: $selectedFolder, isFavorite: $isFavorite, showLabel: false)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    private func performAIAction(_ action: AIAction) {
            let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
            let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty

            guard useGemini || useOpenAI else { return }

            isAIGenerating = true
            HapticService.shared.playImpact()
            withAnimation {
                branchMessage = "ai_thinking".localized(for: preferences.language)
            }

            // Cancelar cualquier generación previa antes de iniciar una nueva
            aiTask?.cancel()
            // Determinar qué fragmento procesar (selección o todo)
            let sourceText = plainTextContent.isEmpty ? content : plainTextContent
            let textToProcess: String
            let rangeToProcess: NSRange
            let fullNSString = sourceText as NSString

            if let sel = selectedRange, sel.length > 0 {
                textToProcess = fullNSString.substring(with: sel)
                rangeToProcess = sel
            } else {
                textToProcess = sourceText
                rangeToProcess = NSRange(location: 0, length: fullNSString.length)
            }

            guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isAIGenerating = false
                return
            }

            let contextInstruction = (action == .instruct) ? "" : "\n\nPrompt Fragment:\n\(textToProcess)"
            let fullPrompt = (action == .instruct) ? "Execute the following instruction/command. Respond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"

            aiTask = Task {
                do {
                    let fullResponse: String
                    if preferences.preferredAIService == .openai {
                        fullResponse = try await OpenAIService.shared.generate(prompt: fullPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
                    } else {
                        fullResponse = try await GeminiService.shared.generate(prompt: fullPrompt, model: preferences.geminiDefaultModel)
                    }
                    
                    await MainActor.run {
                        self.isAIGenerating = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            print("✅ AI Generation Success: \(fullResponse.count) characters")
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.aiResult = AIResult(result: resultString, range: rangeToProcess)
                        } else {
                            print("⚠️ AI Generation Finished with empty response")
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isAIGenerating = false
                        print("❌ AI Generation Error: \(error.localizedDescription)")
                        HapticService.shared.playError()
                        withAnimation {
                            self.branchMessage = self.userFacingAIErrorToast(for: error)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                        }
                }
            }
        }
    }

    private func userFacingAIErrorToast(for error: Error) -> String {
        let nsError = error as NSError

        let baseKey: String = {
            if let openAIError = error as? OpenAIAPIError {
                switch openAIError.kind {
                case .invalidAPIKey: return "ai_error_invalid_api_key"
                case .modelNotFound: return "ai_error_model_not_found"
                case .rateLimited: return "ai_error_rate_limited"
                case .serverBusy: return "ai_error_server_busy"
                case .badRequest: return "ai_error_bad_request"
                case .emptyResponse: return "ai_error_empty_response"
                case .unknown: return "ai_error_unknown"
                }
            }

            if nsError.domain == NSURLErrorDomain {
                return "ai_error_network"
            }

            if nsError.domain == "GeminiAPI" {
                switch nsError.code {
                case 400: return "ai_error_bad_request"
                case 401, 403: return "ai_error_invalid_api_key"
                case 404: return "ai_error_model_not_found"
                case 429: return "ai_error_rate_limited"
                case 500, 502, 503, 504: return "ai_error_server_busy"
                default: return "ai_error_unknown"
                }
            }

            let lower = nsError.localizedDescription.lowercased()
            if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
                return "ai_error_model_not_found"
            }
            if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("429") {
                return "ai_error_rate_limited"
            }
            if lower.contains("invalid api key") || (lower.contains("api key") && lower.contains("invalid")) || lower.contains("401") {
                return "ai_error_invalid_api_key"
            }
            if lower.contains("overloaded") || lower.contains("server busy") || lower.contains("503") {
                return "ai_error_server_busy"
            }

            return "ai_error_unknown"
        }()

        let base = baseKey.localized(for: preferences.language)
        let detail = compactErrorDetail(from: error)
        if detail.isEmpty {
            return "❌ \(base)"
        }
        return "❌ \(base)\n\(detail)"
    }

    private func compactErrorDetail(from error: Error) -> String {
        let raw: String = {
            if let openAIError = error as? OpenAIAPIError {
                return openAIError.message
            }
            return (error as NSError).localizedDescription
        }()

        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return "" }
        if cleaned.count <= 180 { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return String(cleaned[..<idx]) + "…"
    }

    private func createNewPromptFromEditor() {
        let newTitle = "New Prompt from Editor"
        let newPrompt = Prompt(
            title: newTitle,
            content: content,
            folder: (originalPrompt ?? prompt)?.folder,
            icon: (originalPrompt ?? prompt)?.icon ?? "doc.text.fill",
            tags: (originalPrompt ?? prompt)?.tags ?? []
        )

        if promptService.createPrompt(newPrompt) {
            HapticService.shared.playSuccess()
            withAnimation {
                branchMessage = "prompt_created_success".localized(for: preferences.language)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { branchMessage = nil }
            }
        }
    }
}

enum AIAction {
    case enhance, fix, concise, translate, instruct

    var systemPrompt: String {
        switch self {
        case .enhance: return "Enhance the following prompt to be more descriptive and effective, keeping the variables {{...}} exactly as they are. Respond ONLY with the improved prompt text."
        case .fix: return "Fix grammar and spelling errors in the following prompt, keeping variables {{...}} exactly as they are. Respond ONLY with the corrected text."
        case .concise: return "Make the following prompt more concise and direct, keeping variables {{...}} exactly as they are. Respond ONLY with the concise text."
        case .translate: return "Translate the following text to English (if it is in another language) or to Spanish (if it is in English), keeping variables {{...}} exactly as they are. Respond ONLY with the translated text."
        case .instruct: return ""
        }
    }
}

struct SecondaryEditorCard<Actions: View>: View {
    let title: String
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
    
    var isAutocompleting: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager

    init(title: String, placeholder: String, text: Binding<String>, icon: String, color: Color,
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
    }

    private var isAIAvailable: Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }

    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var plainTextContent: String = ""

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

                if String(describing: actions) != "EmptyView" {
                    actions
                        .padding(.leading, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            // ✅ Editor Secundario con Herramientas Inteligentes (Sidebar Layout)
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
                    .padding(.trailing, 5) // Espacio sutil de 5px
                    .frame(maxWidth: .infinity, minHeight: 180) // Aumentado para que sea más espacioso

                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14 * preferences.fontSize.scale))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.leading, 22)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

                // Herramientas Laterales (Compactas)
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
                .padding(.trailing, 4) // Ajustado para ahorrar espacio lateral
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isTyping ? 2 : 1.5)
                            .shadow(color: preferences.isHaloEffectEnabled ? themeColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(isTyping ? .spring(response: 0.35, dampingFraction: 0.7) : .easeOut(duration: 1.5), value: isTyping)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorFocused = true
                }
            }
        }
    }
        private func performAIAction(_ action: AIAction) {
            let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
            let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
            
            guard useGemini || useOpenAI else { return }

            isAIGenerating = true
            HapticService.shared.playImpact()
            withAnimation {
                branchMessage = "ai_thinking".localized(for: preferences.language)
            }

            // Determinar qué fragmento procesar
            let sourceText = plainTextContent.isEmpty ? text : plainTextContent
            let textToProcess: String
            let rangeToProcess: NSRange
            let fullNSString = sourceText as NSString

            if let sel = selectedRange, sel.length > 0 {
                textToProcess = fullNSString.substring(with: sel)
                rangeToProcess = sel
            } else {
                textToProcess = sourceText
                rangeToProcess = NSRange(location: 0, length: fullNSString.length)
            }

            guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isAIGenerating = false
                return
            }

            let contextInstruction = (action == .instruct) ? "" : "\n\nPrompt Fragment:\n\(textToProcess)"
            let fullPrompt = (action == .instruct) ? "Execute the following instruction/command. Respond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"

            Task {
                do {
                    let fullResponse: String
                    if preferences.preferredAIService == .openai {
                        fullResponse = try await OpenAIService.shared.generate(prompt: fullPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
                    } else {
                        fullResponse = try await GeminiService.shared.generate(prompt: fullPrompt, model: preferences.geminiDefaultModel)
                    }
                    
                    await MainActor.run {
                        self.isAIGenerating = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.aiResult = AIResult(result: resultString, range: rangeToProcess)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isAIGenerating = false
                        HapticService.shared.playError()
                        withAnimation {
                            self.branchMessage = self.userFacingAIErrorToast(for: error)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                        }
                    }
                }
            }
        }

        private func userFacingAIErrorToast(for error: Error) -> String {
            let nsError = error as NSError

            let baseKey: String = {
                if let openAIError = error as? OpenAIAPIError {
                    switch openAIError.kind {
                    case .invalidAPIKey: return "ai_error_invalid_api_key"
                    case .modelNotFound: return "ai_error_model_not_found"
                    case .rateLimited: return "ai_error_rate_limited"
                    case .serverBusy: return "ai_error_server_busy"
                    case .badRequest: return "ai_error_bad_request"
                    case .emptyResponse: return "ai_error_empty_response"
                    case .unknown: return "ai_error_unknown"
                    }
                }

                if nsError.domain == NSURLErrorDomain {
                    return "ai_error_network"
                }

                if nsError.domain == "GeminiAPI" {
                    switch nsError.code {
                    case 400: return "ai_error_bad_request"
                    case 401, 403: return "ai_error_invalid_api_key"
                    case 404: return "ai_error_model_not_found"
                    case 429: return "ai_error_rate_limited"
                    case 500, 502, 503, 504: return "ai_error_server_busy"
                    default: return "ai_error_unknown"
                    }
                }

                let lower = nsError.localizedDescription.lowercased()
                if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
                    return "ai_error_model_not_found"
                }
                if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("429") {
                    return "ai_error_rate_limited"
                }
                if lower.contains("invalid api key") || (lower.contains("api key") && lower.contains("invalid")) || lower.contains("401") {
                    return "ai_error_invalid_api_key"
                }
                if lower.contains("overloaded") || lower.contains("server busy") || lower.contains("503") {
                    return "ai_error_server_busy"
                }

                return "ai_error_unknown"
            }()

            let base = baseKey.localized(for: preferences.language)
            let detail = compactErrorDetail(from: error)
            if detail.isEmpty {
                return "❌ \(base)"
            }
            return "❌ \(base)\n\(detail)"
        }

        private func compactErrorDetail(from error: Error) -> String {
            let raw: String = {
                if let openAIError = error as? OpenAIAPIError {
                    return openAIError.message
                }
                return (error as NSError).localizedDescription
            }()

            let cleaned = raw
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if cleaned.isEmpty { return "" }
            if cleaned.count <= 180 { return cleaned }
            let idx = cleaned.index(cleaned.startIndex, offsetBy: 180)
            return String(cleaned[..<idx]) + "…"
        }
    private func createNewPromptFromEditor() {
        let newTitle = "New Prompt from Editor"
        let newPrompt = Prompt(
            title: newTitle,
            content: text,
            folder: (originalPrompt ?? prompt)?.folder,
            icon: "doc.text.fill",
            tags: []
        )

        if promptService.createPrompt(newPrompt) {
            HapticService.shared.playSuccess()
        }
    }
}

// MARK: - Componentes de Soporte de Galería

struct ImageSlotView: View {
    let imageData: Data
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let isSelected: Bool
    let onRemove: () -> Void
    let onPreview: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    let onDragStart: () -> Void

    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var isFillMode = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: isFillMode ? .fill : .fit)
                    .frame(width: slotWidth, height: slotHeight, alignment: .center)
                    .clipped()
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTargeted || isSelected ? Color.blue : Color.primary.opacity(0.05), lineWidth: (isTargeted || isSelected) ? 2.5 : 1)
                    )
                    .onTapGesture(perform: onPreview)
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.image.identifier)
                    }
                    .shadow(color: Color.black.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
                    .scaleEffect(isTargeted ? 1.05 : (isHovering ? 1.015 : 1.0))
                    .animation(.spring(response: 0.3), value: isTargeted)
                    .animation(.spring(response: 0.3), value: isHovering)
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFillMode.toggle()
                            }
                        } label: {
                            Image(systemName: isFillMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(isHovering ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                    }
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3)) {
                            isHovering = hovering
                        }
                    }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .onDrop(of: [.image, .fileURL, .url], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

struct PlaceholderSlotView: View {
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    var tintColor: Color = .blue
    
    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var dashPhase: CGFloat = 0
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 0.8 : 0.4))

            Text("add_prompt_results".localized(for: preferences.language))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 0.8 : 0.4))
        }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .frame(width: slotWidth, height: slotHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? tintColor.opacity(0.1) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        // El lineWidth fijo para hover evita que StrokeStyle anime incorrectamente el dashPhase
                        .stroke(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: isTargeted ? [] : [6, 4], dashPhase: dashPhase))
                        .foregroundColor(isTargeted ? tintColor : .secondary.opacity(isHovering ? 1.0 : 0.8))
                        .animation(.easeInOut(duration: 0.15), value: isHovering)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            AngularGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: tintColor.opacity(0.1), location: 0.3),
                                    .init(color: tintColor.opacity(0.4), location: 0.6),
                                    .init(color: tintColor.opacity(0.7), location: 0.8),
                                    .init(color: tintColor.opacity(0.9), location: 0.95),
                                    .init(color: .clear, location: 1.0)
                                ],
                                center: .center,
                                angle: .degrees(Double(-dashPhase * 24))
                            ),
                            lineWidth: 2.5
                        )
                        .opacity((isHovering || isTargeted) ? 1.0 : 0)
                        .blendMode(.plusLighter)
                        .animation(.easeInOut(duration: 0.3), value: isHovering || isTargeted)
                )
        )
        .scaleEffect(isTargeted ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onReceive(Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()) { _ in
            if isHovering || isTargeted {
                dashPhase -= 0.1
            }
        }
        .onHover { hovering in
            // Cambio de estado sin withAnimation global para evitar saltos
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onDrop(of: [.image, .fileURL, .url], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

// MARK: - Components

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ScaleButtonLabel(configuration: configuration)
    }
    
    struct ScaleButtonLabel: View {
        let configuration: Configuration
        @State private var isHovering = false
        
        var body: some View {
            configuration.label
                .brightness(isHovering ? 0.05 : 0)
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(LocalizedStringKey(title))
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color : color.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : color.opacity(0.15), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : color.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}

// MARK: - AIGeneratingOverlay

struct AIGeneratingOverlay: View {
    let accentColor: Color
    var compact: Bool = false

    @State private var pulse = false
    @State private var shimmer = false
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        ZStack {
            // Capa de vidrio esmerilado
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    accentColor.opacity(0.03)
                )

            // Efectos de luz ambiente
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(pulse ? 0.3 : 0.1))
                    .frame(width: compact ? 100 : 200, height: compact ? 100 : 200)
                    .blur(radius: compact ? 30 : 60)
                    .scaleEffect(pulse ? 1.2 : 0.8)

                Circle()
                    .fill(accentColor.opacity(pulse ? 0.1 : 0.2))
                    .frame(width: compact ? 80 : 150, height: compact ? 80 : 150)
                    .blur(radius: compact ? 25 : 50)
                    .offset(x: pulse ? 20 : -20, y: pulse ? -10 : 10)
            }
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: compact ? 12 : 16) {
                // Icono animado
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 24 : 32, weight: .bold))
                        .foregroundColor(.purple)
                        .symbolEffect(.variableColor.reversing.iterative)

                    Image(systemName: "sparkles")
                        .font(.system(size: compact ? 24 : 32, weight: .bold))
                        .foregroundColor(.purple)
                        .blur(radius: 8)
                        .opacity(pulse ? 0.8 : 0.3)
                }

                VStack(spacing: 4) {
                    Text("ai_thinking".localized(for: preferences.language))
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .foregroundColor(.primary.opacity(0.8))

                    if !compact {
                        Text("ai_crafting_message".localized(for: preferences.language))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Barra de progreso elegante
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: compact ? 100 : 160, height: 4)

                    Capsule()
                        .fill(preferences.isHaloEffectEnabled ?
                            AnyShapeStyle(LinearGradient(colors: [.purple, accentColor], startPoint: .leading, endPoint: .trailing)) :
                            AnyShapeStyle(accentColor))
                        .frame(width: shimmer ? (compact ? 100 : 160) : 0, height: 4)
                }
                .mask(
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing))
                        .offset(x: shimmer ? (compact ? 150 : 250) : (compact ? -150 : -250))
                )
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}

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
}
