//
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import Foundation
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
    
    enum ZenEditorTarget: Identifiable {
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
    @State private var isAIActive: Bool = false
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
                editorID: "main",
                currentCategoryColor: currentCategoryColor
            )
            .frame(minHeight: 380) // Usar minHeight en lugar de frame fijo basado en % para mejor scroll
            
            // SECTION 2: ADVANCED FIELDS
            VStack(spacing: 24) {
                // 2.1: NEGATIVE PROMPT
                SecondaryEditorCard(
                    title: "negative_prompt".localized(for: preferences.language),
                    placeholder: "negative_prompt_placeholder".localized(for: preferences.language),
                    text: $negativePrompt,
                    icon: "minus.circle.fill",
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
                    showingPremiumFor: $showingPremiumFor,
                    editorID: "negative"
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
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("add_alternative".localized(for: preferences.language))
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .id("alternatives_section")
            }
            
            // SECTION 3: UTILITIES
            VStack(alignment: .leading, spacing: 20) {
                // Atajo Individual (Movido aquí para mayor visibilidad)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
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
                            .fill(currentCategoryColor.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(currentCategoryColor.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                
                // Contextual Awareness (App Association)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
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
                            .foregroundColor(.purple)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.08))
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
                            .fill(currentCategoryColor.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(currentCategoryColor.opacity(0.12), lineWidth: 1)
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
            icon: "text.bubble.fill",
            color: .green,
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
            showingPremiumFor: $showingPremiumFor,
            editorID: "alt-\(index)"
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { _ = withAnimation { branchMessage = nil } }
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { _ = withAnimation { branchMessage = nil } }
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
                        alternatives.remove(at: index)
                    }
                    HapticService.shared.playLight()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.6))
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
                            .onChange(of: focusNegative) { isFocused in
                                if isFocused {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            proxy.scrollTo("negative_prompt_section", anchor: .center)
                                        }
                                    }
                                }
                            }
                            .onChange(of: focusAlternative) { isFocused in
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
                    triggerAIRequest: $triggerAIRequest,
                    isAIActive: $isAIActive,
                    showingPremiumFor: $showingPremiumFor
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
            if event.keyCode == 53 && modifiers.isEmpty {
                if self.showSnippets {
                    DispatchQueue.main.async { withAnimation { self.showSnippets = false } }
                    return nil
                }
                
                // Si no hay overlays críticos abiertos, cerrar la vista
                if self.zenTarget == nil && !self.showingIconPicker {
                    // Try to resign first responder to lose focus
                    if let window = NSApp.keyWindow, let _ = window.firstResponder as? NSTextView {
                        DispatchQueue.main.async {
                            window.makeFirstResponder(nil)
                        }
                        return nil // Just lose focus, don't close
                    }
                    
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
            
            // Option + V -> Insert Variable
            if modifiers == .option && event.keyCode == 9 { // keyCode 9 is 'V'
                DispatchQueue.main.async {
                    if self.preferences.isPremiumActive {
                        self.insertionRequest = "{{variable}}"
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
        
        if let prompt = prompt {
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

            // Lazy-load de imágenes (la lista ya no carga blobs para mejorar rendimiento).
            if showcaseImages.isEmpty && prompt.showcaseImageCount > 0 {
                Task(priority: .userInitiated) {
                    if let full = await promptService.fetchPrompt(byId: prompt.id, includeImages: true) {
                        await MainActor.run {
                            self.originalPrompt = full
                            // Evitar pisar cambios del usuario si ya añadió imágenes manualmente.
                            if self.showcaseImages.isEmpty {
                                self.showcaseImages = full.showcaseImages
                            }
                        }
                    }
                }
            }
        } else if let draft = DraftService.shared.loadDraft() {
            // Restaurar borrador si existe y no estamos editando uno específico pasado por parámetro
            let draftPrompt = draft.prompt
            
            // Si el borrador era una edición, intentamos recuperar el original
            if draft.isEditing {
                if let original = promptService.prompts.first(where: { $0.id == draftPrompt.id }) {
                    self.originalPrompt = original
                }
            }
            
            title = draftPrompt.title
            content = draftPrompt.content
            negativePrompt = draftPrompt.negativePrompt ?? ""
            alternatives = draftPrompt.alternatives
            if alternatives.isEmpty, let legacy = draftPrompt.alternativePrompt, !legacy.isEmpty {
                alternatives = [legacy]
            }
            promptDescription = draftPrompt.promptDescription ?? ""
            selectedFolder = draftPrompt.folder
            isFavorite = draftPrompt.isFavorite
            selectedIcon = draftPrompt.icon
            showcaseImages = draftPrompt.showcaseImages
            tags = draftPrompt.tags
            targetAppBundleIDs = draftPrompt.targetAppBundleIDs
            customShortcut = draftPrompt.customShortcut
            isDraftRestored = true
            
            if !negativePrompt.isEmpty { showNegativeField = true }
            if !alternatives.isEmpty { showAlternativeField = true }
            
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
            
            VStack(spacing: 2) {
                Text(prompt != nil ? "edit_prompt".localized(for: preferences.language) : "new_prompt".localized(for: preferences.language))
                    .font(.system(size: 15, weight: .bold))
                Text(prompt != nil ? "update_details".localized(for: preferences.language) : "create_tool".localized(for: preferences.language))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let existing = originalPrompt ?? prompt {
                Button(action: { branchPrompt() }) {
                    Image(systemName: "arrow.branch")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(currentCategoryColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(currentCategoryColor.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("create_branch".localized(for: preferences.language))
                .padding(.trailing, 8)
            }

            Button(action: { savePrompt() }) {
                Text(prompt != nil ? "save".localized(for: preferences.language) : "create".localized(for: preferences.language))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : currentCategoryColor)
                            .shadow(color: title.isEmpty || content.isEmpty ? .clear : currentCategoryColor.opacity(0.2), radius: 4, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(title.isEmpty || content.isEmpty)
            .keyboardShortcut("s", modifiers: [.command]) 
        }
        .frame(width: width)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }
    
                private var imageGallery: some View {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
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
            
            // Círculos decorativos para efecto mesh (Neón sutil)
            Circle()
                .fill(currentCategoryColor.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 250, y: -180)
            
            Circle()
                .fill(currentCategoryColor.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -280, y: 220)
                
            // Brillo ambiental central
            Circle()
                .fill(Color.blue.opacity(0.02))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
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
    let editorID: String
    
    let currentCategoryColor: Color
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isEditorFocused: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Título e Icono (Header del Documento)
            HStack(alignment: .top, spacing: 16) {
                Button(action: { showingIconPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentCategoryColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: selectedIcon ?? fallbackIconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(currentCategoryColor)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                    IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22 * preferences.fontSize.scale, weight: .bold))
                    
                    TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13 * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Toolbar de Acciones (Header)
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        if preferences.appleIntelligenceEnabled {
                            Button(action: {
                                triggerAIRequest = editorID
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: "apple.intelligence")
                                    .font(.system(size: 11, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundColor(currentCategoryColor)
                                    .frame(width: 32, height: 32)
                                    .background(isAIActive ? currentCategoryColor.opacity(0.2) : currentCategoryColor.opacity(0.1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Divider().frame(height: 18).background(currentCategoryColor.opacity(0.2))
                        }

                        Button(action: {
                            if preferences.isPremiumActive {
                                showVariables = true
                                variablesSelectedIndex = 0
                            } else {
                                showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                            }
                        }) {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(currentCategoryColor)
                                .frame(width: 32, height: 32)
                                .background(currentCategoryColor.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Divider().frame(height: 18).background(currentCategoryColor.opacity(0.2))
                        
                        Button(action: {
                            if preferences.isPremiumActive {
                                showSnippets = true
                                snippetSearchQuery = ""
                            } else {
                                showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                            }
                        }) {
                            Text("/")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(currentCategoryColor)
                                .frame(width: 32, height: 32)
                                .background(currentCategoryColor.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Divider().frame(height: 18).background(currentCategoryColor.opacity(0.2))

                        Button(action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingZenEditor = true
                                zenTarget = .main
                            }
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(currentCategoryColor)
                                .frame(width: 32, height: 32)
                                .background(currentCategoryColor.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 24)
            
            // Área de Texto
            VStack(spacing: 0) {
                HighlightedEditor(
                    text: $content,
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    triggerAIRequest: $triggerAIRequest,
                    isAIActive: $isAIActive,
                    editorID: editorID,
                    isFocused: $isEditorFocused,
                    fontSize: 16 * preferences.fontSize.scale,
                    themeColor: NSColor(currentCategoryColor),
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    isPremium: preferences.isPremiumActive
                )
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(currentCategoryColor.opacity(0.05)) // Color profesional sutil
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isEditorFocused ? Color.blue.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isEditorFocused ? 2 : 1)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
            .onTapGesture {
                // Not ideal, but we can't easily force focus into AppKit view from SwiftUI without focusRequest binding.
                // It is already focusable by clicking inside. We will just ensure the view handles its own focus.
                isEditorFocused = true
            }
        }
    }
}

struct SecondaryEditorCard<Actions: View>: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let color: Color
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
    @Binding var showingPremiumFor: String?
    let editorID: String
    
    let actions: Actions
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isEditorFocused: Bool = false
    
    init(title: String, placeholder: String, text: Binding<String>, icon: String, color: Color, 
         focusRequest: Binding<Bool>? = nil, onZenMode: (() -> Void)? = nil,
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>,
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>,
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>,
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>,
         triggerVariablesSelection: Binding<Bool>,
         triggerAIRequest: Binding<String?>, 
          isAIActive: Binding<Bool>,
          showingPremiumFor: Binding<String?>,
          editorID: String,
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
        self._showingPremiumFor = showingPremiumFor
        self.editorID = editorID
        self.actions = actions()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                if String(describing: actions) != "EmptyView" {
                    actions
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        if preferences.appleIntelligenceEnabled {
                            Button(action: {
                                triggerAIRequest = editorID
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: "apple.intelligence")
                                    .font(.system(size: 9, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundColor(color)
                                    .frame(width: 24, height: 24)
                                    .background(isAIActive ? color.opacity(0.2) : color.opacity(0.1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Divider().frame(height: 14).background(color.opacity(0.2))
                        }

                        Button(action: {
                            if preferences.isPremiumActive {
                                showVariables = true
                                variablesSelectedIndex = 0
                            } else {
                                showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                            }
                        }) {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(color)
                                .frame(width: 24, height: 24)
                                .background(color.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Divider().frame(height: 14).background(color.opacity(0.2))
                        
                        Button(action: {
                            if preferences.isPremiumActive {
                                showSnippets = true
                                snippetSearchQuery = ""
                            } else {
                                showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                            }
                        }) {
                            Text("/")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(color)
                                .frame(width: 24, height: 24)
                                .background(color.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        if let onZen = onZenMode {
                            Divider().frame(height: 14).background(color.opacity(0.2))
                            
                            Button(action: onZen) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(color)
                                    .frame(width: 24, height: 24)
                                    .background(color.opacity(0.1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
            }
            
            VStack(spacing: 0) {
                HighlightedEditor(
                    text: $text,
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    triggerAIRequest: $triggerAIRequest,
                    isAIActive: $isAIActive,
                    editorID: editorID,
                    isFocused: $isEditorFocused,
                    focusRequest: focusRequest,
                    fontSize: 14 * preferences.fontSize.scale,
                    themeColor: NSColor(color),
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    isPremium: preferences.isPremiumActive
                )
                .padding(12)
                .frame(minHeight: 120)
                .background(
                    ZStack(alignment: .topLeading) {
                        color.opacity(0.06) // Rojo/Verde sutil profesional
                        
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(12)
                                .padding(.top, 4)
                        }
                    }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isEditorFocused ? color.opacity(0.6) : Color.primary.opacity(0.06), lineWidth: isEditorFocused ? 2 : 1)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
            .onTapGesture {
                isEditorFocused = true
            }
        }
    }
}

// MARK: - Componentes de Soporte de Galería

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
                        .stroke(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [4]))
                        .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.2))
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

// Helper para convertir String a Identifiable para .sheet
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct IdentifiableData: Identifiable {
    let id = UUID()
    let value: Data
}

