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
    @State private var localMonitor: Any? = nil
    @State private var showingDiff: Bool = false
    @State private var branchMessage: String? = nil
    @State private var showingAppPicker = false

    @State private var cancellables = Set<AnyCancellable>()

    // Identificador para rastrear cambios y guardar borradores
    @State private var originalPrompt: Prompt? = nil
    @State private var isDraftRestored = false
    @State private var autoSaveWorkItem: DispatchWorkItem? = nil

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
        preferences.isHaloEffectEnabled ? currentCategoryColor : Color.blue
    }

    private var currentCategoryColor: Color {
        if let folderName = selectedFolder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .blue
        }
        return .blue
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
    }

    @ViewBuilder
    private func mainScrollViewContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 32) {
            // SECTION 1: MAIN PROMPT (Primary Focus)
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
                selectedRange: $selectedRange,
                aiResult: $aiResult,
                originalPrompt: originalPrompt,
                prompt: prompt,
                branchMessage: $branchMessage,
                editorID: "main",
                currentCategoryColor: currentCategoryColor
            )
            .frame(minHeight: geometry.size.height * 0.85)

            // SECTION 2: ADVANCED FIELDS (Unified Group) - Conditionally Visible
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
                            EmptyView()
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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        alternatives.append("")
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

                                            // Fondo traslúcido estilizado
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(themeColor.opacity(0.1))
                                                .background(
                                                    VisualEffectView(material: .popover, blendingMode: .withinWindow)
                                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                                        .opacity(0.6)
                                                )
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
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.06) : Color.primary.opacity(0.03))
                            .background(
                                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .opacity(0.6)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.12) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }

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

                imageGallery
            }
            .padding(.bottom, 40)
        }
        .padding(.vertical, 24)
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
                    .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
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
                        showingDiff = true
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
                .sheet(isPresented: $showingDiff) {
                    DiffView(text1: content, text2: alternatives.first ?? "")
                }
                .onAppear {
                    setupOnAppear()
                    setupKeyboardMonitor()
                }        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
        .onChange(of: draftState) { _, newValue in
            saveCurrentDraft()
            // Maintain the lock on the modal so clicking outside doesn't close it
            MenuBarManager.shared.isModalActive = true
            debounceAutoSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FloatingZenDraftUpdated"))) { _ in
            DispatchQueue.main.async {
                self.setupOnAppear()
            }
        }
    }

    private func debounceAutoSave() {
        autoSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            // Solo auto-guardar si estamos editando un prompt existente
            // Y no guardar si el prompt está vacío
            if originalPrompt != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty && !content.trimmingCharacters(in: .whitespaces).isEmpty {
                savePrompt(closeAfter: false, isAutoSave: true)
            }
        }
        autoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
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
            if showSnippets {
                snippetOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                    .zIndex(200)
            }
            if showVariables {
                variablesOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                    .zIndex(201)
            }
            if showParticles {
                ParticleSystemView(accentColor: currentCategoryColor)
                    .allowsHitTesting(false)
                    .zIndex(300)
            }

            if let msg = branchMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.purple).shadow(radius: 10))
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(400)
            }
        }
    }

    private func setupKeyboardMonitor() {
        if localMonitor != nil { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd + S -> Save
            if modifiers.contains(.command) && event.keyCode == 1 { // 'S' is key code 1
                DispatchQueue.main.async {
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
                    if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
                       let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {

                        DispatchQueue.main.async {
                            if let optimizedData = ImageOptimizer.shared.optimize(imageData: pngData) {
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
                if self.showSnippets {
                    DispatchQueue.main.async { withAnimation { self.showSnippets = false } }
                    return nil
                }
                if self.showVariables {
                    DispatchQueue.main.async { withAnimation { self.showVariables = false } }
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
                        self.onClose()
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

            // Cmd + Shift + Z -> Zen Mode (Z is keyCode 6)
            if modifiers.contains(.command) && modifiers.contains(.shift) && event.keyCode == 6 {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.showingZenEditor.toggle()
                    }
                }
                return nil
            }

            return event
        }
    }

    private func setupOnAppear() {
        // ALWAYS lock modal so clicking outside doesn't close the editor
        MenuBarManager.shared.isModalActive = true

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
            alternatives = prompt.alternatives
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
                    DraftService.shared.clearDraft()
                    MenuBarManager.shared.isModalActive = false
                    onClose()
                }) {
                    Text("cancel".localized(for: preferences.language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 12) {
                    if let msg = branchMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Button(action: {
                        withAnimation(.spring()) {
                            isFavorite.toggle()
                        }
                        HapticService.shared.playAlignment()
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isFavorite ? (preferences.isHaloEffectEnabled ? .yellow : .blue) : themeColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isFavorite ? (preferences.isHaloEffectEnabled ? Color.yellow.opacity(0.1) : Color.blue.opacity(0.1)) : themeColor.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("favorite".localized(for: preferences.language))

                    Button(action: {
                        // Force save current draft state
                        saveCurrentDraft()

                        // Extract title and content to floating manager
                        FloatingZenManager.shared.show(title: title, promptDescription: promptDescription, content: content, promptId: originalPrompt?.id ?? prompt?.id, isEditing: true)
                        // Close popover
                        MenuBarManager.shared.closePopover()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(themeColor.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("Floating Zen Mode")

                    if (originalPrompt ?? prompt) != nil {
                        Button(action: { branchPrompt() }) {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeColor)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(themeColor.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .help("create_branch".localized(for: preferences.language))
                    }

                    Button(action: { savePrompt() }) {
                        Text(prompt != nil ? "save".localized(for: preferences.language) : "create".localized(for: preferences.language))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : (preferences.isHaloEffectEnabled ? currentCategoryColor : .blue))
                                    .shadow(color: title.isEmpty || content.isEmpty ? .clear : (preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(0.2) : .clear), radius: 4, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
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

                private var imageGallery: some View {
                    VStack(alignment: .leading, spacing: 12) {
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
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .help("add_image".localized(for: preferences.language))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)

                        ScrollView(.horizontal, showsIndicators: false) {                HStack(spacing: 12) {
                    // Imágenes actuales
                    ForEach(0..<showcaseImages.count, id: \.self) { index in
                        ImageSlotView(
                            imageData: showcaseImages[index],
                            onRemove: { showcaseImages.remove(at: index) },
                            onPreview: { showingFullScreenImage = showcaseImages[index] },
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                            onDragStart: { self.draggedImageIndex = index }
                        )
                    }

                    // Placeholders para completar hasta 3
                    ForEach(showcaseImages.count..<3, id: \.self) { index in
                        PlaceholderSlotView(
                            onSelect: selectImages,
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) }
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
                    if let nsImage = image as? NSImage,
                       let tiffData = nsImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {

                        DispatchQueue.main.async {
                            if let optimizedData = ImageOptimizer.shared.optimize(imageData: pngData) {
                                self.insertImage(optimizedData, at: index)
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data, let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        DispatchQueue.main.async {
                            self.insertImage(optimizedData, at: index)
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        if url.isFileURL {
                            if let data = try? Data(contentsOf: url),
                               let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                                DispatchQueue.main.async {
                                    self.insertImage(optimizedData, at: index)
                                }
                            }
                        } else {
                            // Descargar imagen de web URL (Chrome/Safari drag)
                            URLSession.shared.dataTask(with: url) { data, _, _ in
                                if let data = data, let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                                    DispatchQueue.main.async {
                                        self.insertImage(optimizedData, at: index)
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
            } else {
                showcaseImages.append(data)
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
                        title:     existingPrompt.title,
                        content:   existingPrompt.content,
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

            if isAutoSave {
                DispatchQueue.main.async { self.originalPrompt = updated }
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
            // Limpiar mensaje tras 3 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { branchMessage = nil }
            }
        }
    }

    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            for url in panel.urls {
                if showcaseImages.count < 3 {
                    if let data = try? Data(contentsOf: url),
                       let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        showcaseImages.append(optimizedData)
                    }
                }
            }
        }
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

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : .blue
    }

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 0) {
            // Título, Icono y Descripción (Header Expandido)
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    Button(action: { showingIconPicker.toggle() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(currentCategoryColor.opacity(0.1))
                                .frame(width: 56, height: 56)

                            Image(systemName: selectedIcon ?? fallbackIconName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(currentCategoryColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                        IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 23 * preferences.fontSize.scale, weight: .bold))
                            .lineLimit(2)
                            .padding(.bottom, 2)

                        TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14 * preferences.fontSize.scale, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                            .frame(minHeight: 32, alignment: .topLeading)
                    }
                }
            } // Cierre de la cabecera (VStack en 1695)

            // ✅ Editor Principal con Herramientas Inteligentes (Sidebar Layout)
            HStack(alignment: .top, spacing: 0) {
                // El Editor
                HighlightedEditor(
                    text: $content,
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
                    isHaloEffectEnabled: preferences.isHaloEffectEnabled
                )
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .padding(.trailing, 5) // Espacio sutil de 5px
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)

                // Barra de Herramientas Lateral
                EditorToolbar(
                    color: currentCategoryColor,
                    vertical: true,
                    isAIGenerating: isAIGenerating,
                    onAIAction: { performAIAction($0) },
                    ollamaEnabled: preferences.ollamaEnabled,
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
                    onZenMode: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingZenEditor = true
                            zenTarget = .main
                        }
                    }
                )
                .padding(.vertical, 8)
                .padding(.trailing, 4) // Ajustado para dar más espacio al texto
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(isEditorFocused ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isEditorFocused ? 2 : 1.5)
                            .shadow(color: preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(isEditorFocused ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isEditorFocused ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .padding(.top, 14) // Espacio EXTERNO entre descripción y caja del editor
            .overlay {
                if isAIGenerating {
                    AIGeneratingOverlay(accentColor: themeColor)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorFocused = true
                }
            }

            // ✅ Selector de Categoría (Independiente abajo)
            CategoryPillPicker(selectedCategory: $selectedFolder, isFavorite: $isFavorite, showLabel: false)
                .padding(.horizontal, 8)
                .padding(.top, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
        private func performAIAction(_ action: AIAction) {
            let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
            let useOllama = preferences.ollamaEnabled && OllamaService.shared.selectedModel != nil

            guard useGemini || useOllama else { return }

            isAIGenerating = true
            HapticService.shared.playImpact()

            // Determinar qué fragmento procesar (selección o todo)
            let textToProcess: String
            let rangeToProcess: NSRange
            let fullNSString = content as NSString

            if let sel = selectedRange, sel.length > 0 {
                textToProcess = fullNSString.substring(with: sel)
                rangeToProcess = sel
            } else {
                textToProcess = content
                rangeToProcess = NSRange(location: 0, length: fullNSString.length)
            }

            guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isAIGenerating = false
                return
            }

            let contextInstruction = (action == .instruct) ? "" : "\n\nPrompt Fragment:\n\(textToProcess)"
            let fullPrompt = (action == .instruct) ? "Execute the following instruction/command. Respond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"

            var fullResponse = ""
            let publisher: AnyPublisher<String, Error>

            if useGemini {
                publisher = GeminiService.shared.generate(prompt: fullPrompt)
            } else {
                let model = OllamaService.shared.selectedModel!
                publisher = OllamaService.shared.generate(prompt: fullPrompt, model: model)
            }

            publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    isAIGenerating = false
                    if case .failure = completion {
                        HapticService.shared.playError()
                    } else {
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            aiResult = AIResult(result: resultString, range: rangeToProcess)
                        }
                    }
                }, receiveValue: { chunk in
                    fullResponse += chunk
                })
                .store(in: &cancellables)
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
    case enhance, fix, concise, instruct

    var systemPrompt: String {
        switch self {
        case .enhance: return "Enhance the following prompt to be more descriptive and effective, keeping the variables {{...}} exactly as they are. Respond ONLY with the improved prompt text."
        case .fix: return "Fix grammar and spelling errors in the following prompt, keeping variables {{...}} exactly as they are. Respond ONLY with the corrected text."
        case .concise: return "Make the following prompt more concise and direct, keeping variables {{...}} exactly as they are. Respond ONLY with the concise text."
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

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager

    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var cancellables = Set<AnyCancellable>()

    init(title: String, placeholder: String, text: Binding<String>, icon: String, color: Color,
         focusRequest: Binding<Bool>? = nil, onZenMode: (() -> Void)? = nil,
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>,
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>,
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>,
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>,
         triggerVariablesSelection: Binding<Bool>,
         triggerAIRequest: Binding<String?>,
         isAIActive: Binding<Bool>,
         isAIGenerating: Binding<Bool>,
         selectedRange: Binding<NSRange?>,
         aiResult: Binding<AIResult?>,
         showingPremiumFor: Binding<String?>,
         originalPrompt: Prompt?,
         prompt: Prompt?,
         branchMessage: Binding<String?>,
         editorID: String,
         currentCategoryColor: Color,
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
        self.originalPrompt = originalPrompt
        self.prompt = prompt
        self._branchMessage = branchMessage
        self.editorID = editorID
        self.currentCategoryColor = currentCategoryColor
        self.actions = actions()
    }

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
                        isHaloEffectEnabled: preferences.isHaloEffectEnabled
                    )
                    .padding(.vertical, 12)
                    .padding(.leading, 12)
                    .padding(.trailing, 5) // Espacio sutil de 5px
                    .frame(maxWidth: .infinity, minHeight: 180) // Aumentado para que sea más espacioso

                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14 * preferences.fontSize.scale))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(12)
                            .padding(.top, 4)
                            .allowsHitTesting(false)
                    }
                }

                // Herramientas Laterales (Compactas)
                EditorToolbar(
                    color: color,
                    vertical: true,
                    isAIGenerating: isAIGenerating,
                    onAIAction: { performAIAction($0) },
                    ollamaEnabled: preferences.ollamaEnabled && preferences.localAIToolsEnabled,
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
                    onZenMode: {
                        onZenMode?()
                    }
                )
                .scaleEffect(0.9)
                .padding(.vertical, 8)
                .padding(.trailing, 4) // Ajustado para ahorrar espacio lateral
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(isEditorFocused ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isEditorFocused ? 2 : 1.5)
                            .shadow(color: preferences.isHaloEffectEnabled ? themeColor.opacity(isEditorFocused ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isEditorFocused ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .overlay {
                if isAIGenerating {
                    AIGeneratingOverlay(accentColor: themeColor, compact: true)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
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
            let useOllama = preferences.ollamaEnabled && OllamaService.shared.selectedModel != nil

            guard useGemini || useOllama else { return }

            isAIGenerating = true
            HapticService.shared.playImpact()

            // Determinar qué fragmento procesar
            let textToProcess: String
            let rangeToProcess: NSRange
            let fullNSString = text as NSString

            if let sel = selectedRange, sel.length > 0 {
                textToProcess = fullNSString.substring(with: sel)
                rangeToProcess = sel
            } else {
                textToProcess = text
                rangeToProcess = NSRange(location: 0, length: fullNSString.length)
            }

            guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isAIGenerating = false
                return
            }

            let contextInstruction = (action == .instruct) ? "" : "\n\nPrompt Fragment:\n\(textToProcess)"
            let fullPrompt = (action == .instruct) ? "Execute the following instruction/command. Respond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"

            var fullResponse = ""
            let publisher: AnyPublisher<String, Error>

            if useGemini {
                publisher = GeminiService.shared.generate(prompt: fullPrompt)
            } else {
                let model = OllamaService.shared.selectedModel!
                publisher = OllamaService.shared.generate(prompt: fullPrompt, model: model)
            }

            publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    isAIGenerating = false
                    if case .failure = completion {
                        HapticService.shared.playError()
                    } else {
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            aiResult = AIResult(result: resultString, range: rangeToProcess)
                        }
                    }
                }, receiveValue: { chunk in
                    fullResponse += chunk
                })
                .store(in: &cancellables)
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

// MARK: - Componentes de Soporte de Galería

    }

struct ImageSlotView: View {
    let imageData: Data
    let onRemove: () -> Void
    let onPreview: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    let onDragStart: () -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 120, alignment: .center)
                    .clipped()
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTargeted ? Color.blue : Color.primary.opacity(0.05), lineWidth: isTargeted ? 2 : 1)
                    )
                    .onTapGesture(perform: onPreview)
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.image.identifier)
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    .scaleEffect(isTargeted ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isTargeted)

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
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Void

    @State private var isTargeted = false
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.4))

            Text("add_prompt_results".localized(for: preferences.language))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.4))
        }
        .frame(width: 180, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: isTargeted ? [] : [6, 4]))
                        .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.8))
                )
        )
        .scaleEffect(isTargeted ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .onDrop(of: [.image, .fileURL, .url], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

// MARK: - Components

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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

