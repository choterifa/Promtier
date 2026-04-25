import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class HoverPrewarmCoordinator {
    private enum Throttle {
        static let hoverBurstInterval: CFTimeInterval = 0.055
        static let hoverBurstThreshold = 4
        static let hoverSuppressionWindow: CFTimeInterval = 0.28
    }

    private var hoverPrewarmTask: Task<Void, Never>? = nil
    private var pendingPromptId: UUID? = nil
    private var hoveredPromptId: UUID? = nil
    private var lastHoverEventTimestamp: CFTimeInterval = 0
    private var hoverBurstCount: Int = 0
    private var suppressHoverPrewarmUntil: CFTimeInterval = 0

    func handleHover(
        prompt: Prompt,
        isHovering: Bool,
        prewarmAction: @escaping (Prompt) -> Void
    ) {
        if isHovering {
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastHoverEventTimestamp < Throttle.hoverBurstInterval {
                hoverBurstCount += 1
            } else {
                hoverBurstCount = 0
            }
            lastHoverEventTimestamp = now

            if hoverBurstCount >= Throttle.hoverBurstThreshold {
                suppressHoverPrewarmUntil = now + Throttle.hoverSuppressionWindow
            }

            if now < suppressHoverPrewarmUntil {
                if hoveredPromptId == prompt.id {
                    hoveredPromptId = nil
                }
                cancelPendingPrewarmIfNeeded(for: prompt.id)
                return
            }

            hoveredPromptId = prompt.id
            schedulePrewarm(for: prompt, action: prewarmAction)
            return
        }

        if hoveredPromptId == prompt.id {
            hoveredPromptId = nil
        }
        cancelPendingPrewarmIfNeeded(for: prompt.id)
    }

    func cancelAll() {
        hoverPrewarmTask?.cancel()
        hoverPrewarmTask = nil
        pendingPromptId = nil
        hoveredPromptId = nil
    }

    private func cancelPendingPrewarmIfNeeded(for promptId: UUID) {
        guard pendingPromptId == promptId else { return }
        hoverPrewarmTask?.cancel()
        hoverPrewarmTask = nil
        pendingPromptId = nil
    }

    private func schedulePrewarm(for prompt: Prompt, action: @escaping (Prompt) -> Void) {
        hoverPrewarmTask?.cancel()
        pendingPromptId = prompt.id

        hoverPrewarmTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard hoveredPromptId == prompt.id else { return }
                action(prompt)
            }
        }
    }
}

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
    enum PreviewPrewarmProfile {
        static let maxPixelSize = 1120
    }

    enum InteractionThrottle {
        static let keyboardRepeatMinInterval: CFTimeInterval = 0.012
        static let keyboardPreviewOpenMinInterval: CFTimeInterval = 0.03
        static let keyboardNavigationIdleDelayNanos: UInt64 = 130_000_000
        static let keyboardPreviewRefreshDebounceNanos: UInt64 = 95_000_000
    }

    struct FolderPresentation {
        let color: Color
        let icon: String?
    }

    enum PromptCopyFormat {
        case plainText
        case markdown
        case richText
        case pack
    }

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    @EnvironmentObject var imageStore: ImageStore
    @Environment(\.colorScheme) var colorScheme
    
    @FocusState var isSearchFocused: Bool
    @State var hoverPrewarmCoordinator = HoverPrewarmCoordinator()
    @State var localEventMonitor: Any?
    @State var selectedPrompt: Prompt?
    @State var showingPreview = false
    @State var fillingVariablesFor: Prompt?
    @State var isUserNavigating: Bool = false
    @State var showParticles: Bool = false
    @State var isDraggingFile: Bool = false
    @State var importMessage: String? = nil
    @State var showingImportAlert: Bool = false
    @State var importData: Data? = nil
    @State var importURL: URL? = nil
    /// Bloquea atajos de teclado cuando hay una hoja/modal secundaria abierta
    @State var isFullScreenImageOpen: Bool = false
    // Prewarm de preview/texto para evitar beachball al abrir preview tras arrancar.
    @State var prewarmTask: Task<Void, Never>? = nil
    @State var secondaryImagePrewarmTask: Task<Void, Never>? = nil
    @State var delayedPrewarmTask: Task<Void, Never>? = nil
    @State var previewPrefetchTask: Task<Void, Never>? = nil
    @State var lastPrewarmedPreviewKey: String? = nil
    @State var lastSecondaryImagePrewarmKey: String? = nil
    @State var prefetchedPreviewPaths: [String] = []
    @State var prefetchedPreviewPromptId: UUID? = nil
    @State var previewPathsCache: [UUID: [String]] = [:]
    @State var previewCacheOrder: [UUID] = []
    @State var lastKeyboardNavigationTimestamp: CFTimeInterval = 0
    @State var keyboardNavigationIdleTask: Task<Void, Never>? = nil
    @State var keyboardPreviewRefreshTask: Task<Void, Never>? = nil
    
    @State var isPlusHovered = false
    @State var isBatchHovered = false
    @State var isSettingsHovered = false
    @State var isViewToggleHovered = false
    
    // Ghost Tips logic
    var selectedPromptCategoryColor: Color {
        guard let p = selectedPrompt, let folderName = p.folder else {
            return .blue // Fallback
        }
        if let folder = promptService.folders.first(where: { $0.name == folderName }) {
            return Color(hex: folder.displayColor)
        }
        return .blue
    }
    
    @State var currentGhostTip: GhostTip? = nil
    @State var nextTipIndex: Int = 0
    @State var isGhostTipSuppressedByClipboard = false
    @State var ghostTipTask: Task<Void, Never>? = nil
    private var ghostTips: [GhostTip] {
        [
            // Navegación y Lista
            GhostTip(title: "gt_move_selection".localized(for: preferences.language), icon: "arrow.up", shortcut: "gt_move_shortcut".localized(for: preferences.language)),
            GhostTip(title: "preview".localized(for: preferences.language), icon: "eye", shortcut: "gt_spacebar".localized(for: preferences.language)),
            GhostTip(title: "copy".localized(for: preferences.language), icon: "doc.on.doc", shortcut: "Cmd + C"),
            GhostTip(title: "edit".localized(for: preferences.language), icon: "pencil", shortcut: "gt_edit_shortcut".localized(for: preferences.language)),
            GhostTip(title: "gt_edit_from_preview".localized(for: preferences.language), icon: "pencil.and.outline", shortcut: "E"),
            GhostTip(title: "toggle_sidebar".localized(for: preferences.language), icon: "sidebar.left", shortcut: "Cmd + B"),
            GhostTip(title: "new_prompt".localized(for: preferences.language), icon: "plus", shortcut: "Cmd + N"),
            GhostTip(title: "gallery_toggle".localized(for: preferences.language), icon: "square.grid.2x2", shortcut: "Cmd + G"),
            
            // Atajos Personalizables (Globales)
            GhostTip(title: "gt_fast_add_title".localized(for: preferences.language), icon: "bolt.fill", shortcut: preferences.shortcutDisplayString(keyCode: preferences.fastAddHotkeyCode, modifiers: preferences.fastAddHotkeyModifiers)),
            GhostTip(title: "AI Quick Draft", icon: "sparkles", shortcut: "\("double_tap_right_option".localized(for: preferences.language)) / \(preferences.shortcutDisplayString(keyCode: preferences.aiDraftHotkeyCode, modifiers: preferences.aiDraftHotkeyModifiers))"),
            GhostTip(title: "gt_create_category_title".localized(for: preferences.language), icon: "folder.badge.plus", shortcut: preferences.shortcutDisplayString(keyCode: preferences.categoryHotkeyCode, modifiers: preferences.categoryHotkeyModifiers)),
            
            GhostTip(title: "settings".localized(for: preferences.language), icon: "gearshape", shortcut: "Cmd + ,"),
            
            // Editor
            GhostTip(title: "gt_save_prompt".localized(for: preferences.language), icon: "square.and.arrow.down", shortcut: "Cmd + S"),
            GhostTip(title: "gt_snippets_shortcut".localized(for: preferences.language), icon: "text.quote", shortcut: "/"),
            GhostTip(title: "insert_variable".localized(for: preferences.language), icon: "curlybraces", shortcut: "gt_variables_shortcut".localized(for: preferences.language)),
            GhostTip(title: "focus_negative".localized(for: preferences.language), icon: "minus.circle", shortcut: "⌥ N"),
            GhostTip(title: "focus_alternative".localized(for: preferences.language), icon: "plus.circle", shortcut: "⌥ A"),
            
            // Format & Magic
            GhostTip(title: "gt_magic_autocomplete".localized(for: preferences.language), icon: "wand.and.stars", shortcut: "Cmd + J"),
            GhostTip(title: "gt_bold".localized(for: preferences.language), icon: "bold", shortcut: "Cmd + B"),
            GhostTip(title: "gt_italic".localized(for: preferences.language), icon: "italic", shortcut: "Cmd + I"),
            GhostTip(title: "gt_list".localized(for: preferences.language), icon: "list.bullet", shortcut: "Cmd + ⇧ + L"),
            
            // Variables y Otros
            GhostTip(title: "copy_final_prompt".localized(for: preferences.language), icon: "doc.on.doc.fill", shortcut: "gt_copy_final_shortcut".localized(for: preferences.language)),
            GhostTip(title: "cancel_close".localized(for: preferences.language), icon: "xmark.square", shortcut: "gt_close_window_shortcut".localized(for: preferences.language)),
             GhostTip(title: "gt_drag_images".localized(for: preferences.language), icon: "photo", shortcut: "gt_images_hint".localized(for: preferences.language)),
            GhostTip(title: "gt_zoom_images".localized(for: preferences.language), icon: "magnifyingglass", shortcut: "gt_zoom_hint".localized(for: preferences.language))
        ]
    }

    var folderPresentationByName: [String: FolderPresentation] {
        Dictionary(uniqueKeysWithValues: promptService.folders.map {
            ($0.name, FolderPresentation(color: Color(hex: $0.displayColor), icon: $0.icon))
        })
    }
    
    @ViewBuilder
    private var activeViewContent: some View {
        switch menuBarManager.activeViewState {
        case .main:
            mainView
                .overlay(alignment: .bottom) {
                    if let suggestedContent = menuBarManager.suggestedClipboardContent {
                        ClipboardSuggestionBanner(content: suggestedContent)
                            .padding(.bottom, 32)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                            .zIndex(70)
                    }
                }
                .transition(.opacity)
        case .newPrompt:
            NewPromptView(prompt: selectedPrompt ?? menuBarManager.promptToEditFromOmniSearch, onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedPrompt = nil
                    menuBarManager.promptToEditFromOmniSearch = nil
                    menuBarManager.activeViewState = .main
                }
            })
            .environmentObject(promptService)
            .environmentObject(preferences)
            .environmentObject(menuBarManager)
            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
        case .preferences:
            PreferencesView(onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .main
                }
            })
            .environmentObject(preferences)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
        case .folderManager:
            FolderManagerView(folderToEdit: menuBarManager.folderToEdit, onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.folderToEdit = nil // Limpiar al cerrar
                    menuBarManager.activeViewState = .main
                }
            })
            .environmentObject(promptService)
            .environmentObject(preferences)
            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
        }
    }

    var body: some View {
        ZStack {
            activeViewContent
            
            // Overlay de Variables Dinámicas
            if let prompt = fillingVariablesFor {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation { fillingVariablesFor = nil }
                            }
                        
                        VariableFillView(prompt: prompt, onCopy: { finalContent in
                            ClipboardService.shared.copyToClipboard(finalContent)
                            promptService.recordPromptUse(prompt)
                            withAnimation { fillingVariablesFor = nil }
                            
                            if preferences.soundEnabled {
                                SoundService.shared.playCopySound()
                            }
                            
                            if preferences.isPremiumActive && preferences.visualEffectsEnabled {
                                showParticles = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    showParticles = true
                                }
                            }
                            
                            if preferences.closeOnCopy {
                                if preferences.isPremiumActive && preferences.visualEffectsEnabled {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        menuBarManager.closePopover()
                                    }
                                } else {
                                    menuBarManager.closePopover()
                                }
                            }
                        }, onCancel: {
                            withAnimation { fillingVariablesFor = nil }
                        })
                        .frame(maxHeight: geo.size.height * 0.80)
                        .transition(.scale.combined(with: .opacity))
                        .environmentObject(preferences)
                    }
                }
                .zIndex(100)
                .transition(.opacity)
            }
            
            // Guía de Redimensionado Global
            if preferences.isResizingVisible {
                ResizingGuideView()
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Efectos Visuales
            if showParticles {
                ParticleSystemView(accentColor: .blue)
                    .allowsHitTesting(false)
                    .zIndex(300)
            }
            
            // Handle de Redimensionado Manual (Esquina Inferior Derecha)
            ResizeHandle()
                .zIndex(400)
            
            // Overlay de Ghost Tips
            if let tip = currentGhostTip, preferences.ghostTipsEnabled && menuBarManager.activeViewState == .main && menuBarManager.suggestedClipboardContent == nil && !isGhostTipSuppressedByClipboard {
                VStack {
                    Spacer()
                    GhostTipView(tip: tip, highlightColor: selectedPromptCategoryColor) {
                        currentGhostTip = nil
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
                .padding(.bottom, 24)
                .zIndex(500)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(preferences.appearance == .dark ? .dark : (preferences.appearance == .light ? .light : nil))
        .onDrop(of: [UTType.fileURL, UTType.json, UTType.zip], isTargeted: $isDraggingFile) { providers in
            handleFileDrop(providers: providers)
            return true
        }
        .onChange(of: menuBarManager.suggestedClipboardContent) { _, newValue in
            if newValue == nil {
                // El banner de sugerencia desapareció (por tiempo o manual)
                // Suprimimos los Ghost Tips por 20 segundos para no saturar al usuario
                isGhostTipSuppressedByClipboard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                    isGhostTipSuppressedByClipboard = false
                }
            }
        }
        .onChange(of: menuBarManager.activeViewState) { _, newValue in
            if newValue == .main {
                // Darle tiempo antes de aparecer cuando regresa a main (Triplicado)
                scheduleNextGhostTip(initialDelay: 30.0)
            } else {
                // Ocultar si sale de main
                withAnimation { currentGhostTip = nil }
                ghostTipTask?.cancel()
                ghostTipTask = nil
            }
        }
        .overlay {
            importOverlays
        }
        .alert("import_data_alert_title".localized(for: preferences.language), isPresented: $showingImportAlert) {
            Button("import_button".localized(for: preferences.language), role: .none) {
                let localized = "import_completed_message".localized(for: preferences.language)
                DispatchQueue.global(qos: .userInitiated).async {
                    if let url = importURL, url.pathExtension.lowercased() == "zip" {
                        let results = promptService.importBackupZip(from: url)
                        DispatchQueue.main.async {
                            importMessage = String(format: localized, results.success)
                            HapticService.shared.playStrong()
                            showParticles = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showParticles = false }
                        }
                    } else if let data = importData {
                        let results = promptService.importPromptsFromData(data)
                        DispatchQueue.main.async {
                            importMessage = String(format: localized, results.success)
                            HapticService.shared.playStrong()
                            showParticles = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showParticles = false }
                        }
                    }
                }
            }
            Button("cancel".localized(for: preferences.language), role: .cancel) {
                importData = nil
                importURL = nil
            }
        } message: {
            Text("import_confirmation_message".localized(for: preferences.language))
        }
        .onChange(of: preferences.windowWidth) { _, newWidth in
            handleWindowResize(newWidth)
        }
        .onAppear {
            if localEventMonitor == nil {
                localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    return handleLocalKeyEvent(event)
                }
            }
            
            // Programar primer Ghost Tip si están activados (Triplicado)
            if preferences.ghostTipsEnabled {
                scheduleNextGhostTip(initialDelay: 9.0)
            }
            
            delayedPrewarmTask?.cancel()
            coordinateSelectionAndPrewarm(forcePrimaryPrewarm: true)
        }
        .onChange(of: menuBarManager.promptIdToNavigate) { _, newId in
            if let id = newId {
                handleDeepLinkNavigation(id: id)
            }
        }
        .onDisappear {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
            prewarmTask?.cancel()
            secondaryImagePrewarmTask?.cancel()
            previewPrefetchTask?.cancel()
            delayedPrewarmTask?.cancel()
            hoverPrewarmCoordinator.cancelAll()
            keyboardNavigationIdleTask?.cancel()
            keyboardPreviewRefreshTask?.cancel()
        }
        // Quitar el foco del buscador CADA VEZ que el popover se abre
        .onChange(of: menuBarManager.isPopoverShown) { _, isShown in
            if isShown {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFocused = false
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
        .onChange(of: selectedPrompt?.id) { _, _ in
            handleSelectedPromptChanged()
        }
        .onChange(of: showingPreview) { _, isShown in
            if !isShown {
                isFullScreenImageOpen = false
                previewPrefetchTask?.cancel()
                prewarmTask?.cancel()
                secondaryImagePrewarmTask?.cancel()
                keyboardPreviewRefreshTask?.cancel()
                keyboardNavigationIdleTask?.cancel()
                isUserNavigating = false
            }
        }
        .onChange(of: promptService.filteredPrompts.map(\.id)) { _, _ in
            coordinateSelectionAndPrewarm()
        }
        .onChange(of: promptService.filteredPrompts.first?.id) { _, newValue in
            guard let newValue,
                  let firstPrompt = promptService.filteredPrompts.first(where: { $0.id == newValue }) else { return }

            if selectedPrompt?.id != firstPrompt.id {
                prewarmSecondaryImageAssets(for: firstPrompt, force: true)
            }
            coordinateSelectionAndPrewarm(forcePrimaryPrewarm: true)
        }
        .onReceive(promptService.$prompts) { _ in
            refreshSelectedPromptFromStore()
            coordinateSelectionAndPrewarm()
        }
        .onChange(of: menuBarManager.externalPromptTrigger?.id) { _, newId in
            if let newId = newId, let prompt = menuBarManager.externalPromptTrigger, prompt.id == newId {
                usePrompt(prompt)
                menuBarManager.externalPromptTrigger = nil
            }
        }    }
    
    private var mainView: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                // Sidebar de categorías
                if preferences.showSidebar {
                    CategorySidebar()
                        .frame(width: preferences.sidebarWidth)
                        .environmentObject(promptService)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .overlay(alignment: .trailing) {
                            SidebarResizer()
                        }
                }
                
                // Contenido principal
                VStack(spacing: 0) {
                    SearchHeaderView(
                        isSearchFocused: $isSearchFocused,
                        onNewPrompt: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPrompt = nil
                                menuBarManager.activeViewState = .newPrompt
                            }
                        },
                        onSettings: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                menuBarManager.activeViewState = .preferences
                            }
                        }
                    )
                    
                    Divider().padding(.leading, 14).padding(.trailing, 24)
                    
                    SearchPromptListView(
                        selectedPrompt: $selectedPrompt,
                        showingPreview: $showingPreview,
                        isSearchFocused: $isSearchFocused,
                        isUserNavigating: $isUserNavigating,
                        isPerformanceCardMode: isPerformanceCardMode,
                        categoryColor: categoryColor(for:),
                        resolvedIcon: resolvedIcon(for:),
                        onSelect: { prompt in onSelectPrompt(prompt) },
                        onDoubleTap: { prompt in 
                            isUserNavigating = false
                            selectedPrompt = latestPrompt(for: prompt)
                            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                        },
                        onUse: { prompt in usePrompt(prompt) },
                        onCopyPack: { prompt in copyPromptPack(prompt) },
                        onHover: { prompt, hovering in handlePromptHover(prompt, isHovering: hovering) },
                        contextMenu: { prompt in AnyView(promptContextMenu(for: prompt)) },
                        previewPopover: { prompt, content in AnyView(previewPopoverIfSelected(for: prompt) { content }) }
                    )
                }
            }
            .coordinateSpace(name: "sidebarContainer")
            
            if batchService.isSelectionModeActive && !batchService.selectedPromptIds.isEmpty {
                BatchToolbarView()
                    .padding(.bottom, 14)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(60)
            }
        }
    }

    // searchHeaderView extraído a Componente

    // promptContentView extraído a Componente





    func selectedPreviewPopoverBinding(for promptId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                showingPreview && selectedPrompt?.id == promptId
            },
            set: { isPresented in
                if !isPresented, selectedPrompt?.id == promptId {
                    closePreviewImmediately(playSound: false)
                }
            }
        )
    }

    func closePreviewImmediately(playSound: Bool) {
        guard showingPreview else { return }

        previewPrefetchTask?.cancel()
        prewarmTask?.cancel()
        secondaryImagePrewarmTask?.cancel()
        hoverPrewarmCoordinator.cancelAll()
        keyboardPreviewRefreshTask?.cancel()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showingPreview = false
        }

        isFullScreenImageOpen = false

        if playSound, preferences.soundEnabled {
            SoundService.shared.playPreviewSound()
        }
    }

    func openEditorForSelection() {
        guard selectedPrompt != nil else { return }
        withAnimation(.spring()) {
            menuBarManager.activeViewState = .newPrompt
        }
    }

    func openFolderManagerForSelectedCategory() {
        guard let categoryName = promptService.selectedCategory,
              let folder = promptService.folders.first(where: { $0.name == categoryName }) else { return }

        menuBarManager.folderToEdit = folder
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            menuBarManager.activeViewState = .folderManager
        }
        HapticService.shared.playLight()
    }

    private func toggleSidebarShortcut() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            preferences.showSidebar.toggle()
        }
    }

    private func toggleGridShortcut() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            preferences.isGridView.toggle()
            if preferences.autoHideSidebarInGallery {
                preferences.showSidebar = !preferences.isGridView
            }
        }
    }

    private func shouldThrottleKeyboardNavigation(for event: NSEvent) -> Bool {
        let minInterval: CFTimeInterval
        if showingPreview {
            minInterval = InteractionThrottle.keyboardPreviewOpenMinInterval
        } else if event.isARepeat {
            minInterval = InteractionThrottle.keyboardRepeatMinInterval
        } else {
            minInterval = 0
        }

        let now = CFAbsoluteTimeGetCurrent()
        if minInterval > 0,
           now - lastKeyboardNavigationTimestamp < minInterval {
            return true
        }

        lastKeyboardNavigationTimestamp = now
        return false
    }

    func markUserNavigationActivity() {
        isUserNavigating = true
        keyboardNavigationIdleTask?.cancel()
        keyboardNavigationIdleTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: InteractionThrottle.keyboardNavigationIdleDelayNanos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isUserNavigating = false
            }
        }
    }

    func scheduleKeyboardPreviewRefresh(for prompt: Prompt) {
        guard showingPreview else { return }

        keyboardPreviewRefreshTask?.cancel()
        let expectedPromptId = prompt.id

        keyboardPreviewRefreshTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: InteractionThrottle.keyboardPreviewRefreshDebounceNanos)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard showingPreview,
                      selectedPrompt?.id == expectedPromptId else { return }

                let latest = latestPrompt(for: prompt)
                refreshPreviewPrefetchIfNeeded(for: latest)
                prewarmPreviewAssets(for: latest)
            }
        }
    }

    @ViewBuilder
    func previewPopoverIfSelected<Content: View>(for prompt: Prompt, @ViewBuilder content: () -> Content) -> some View {
        content()
            .popover(isPresented: selectedPreviewPopoverBinding(for: prompt.id), arrowEdge: .top) {
                PromptPreviewView(
                    prompt: selectedPrompt ?? prompt,
                    prefetchedShowcasePaths: (prefetchedPreviewPromptId == prompt.id) ? prefetchedPreviewPaths : nil,
                    isFullScreenImageOpen: $isFullScreenImageOpen,
                    onUse: { usePrompt(prompt) }
                )
            }
    }

    
    func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Ignorar eventos de teclado si hay otras ventanas modales flotantes activas
        if OmniSearchManager.shared.isVisible ||
           FloatingZenManager.shared.isVisible ||
           FloatingAIDraftManager.shared.isVisible ||
           FloatingOnboardingManager.shared.isVisible {
            return event
        }
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if keyCode == 53 && modifiers.isEmpty {
            if fillingVariablesFor != nil {
                withAnimation {
                    fillingVariablesFor = nil
                }
                return nil
            }
            if showingPreview {
                closePreviewImmediately(playSound: true)
                return nil
            }
            let currentState = menuBarManager.activeViewState
            // En el editor (NewPromptView) dejamos que ese view maneje ESC primero
            // (overlays de variables/snippets, perder foco, etc.)
            if currentState == .newPrompt {
                return event
            }
            if currentState != .main {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    menuBarManager.activeViewState = .main
                    // No limpiar selectedPrompt al volver a .main:
                    // Si lo limpiamos, las flechas y Space dejan de funcionar
                    // porque no hay selección activa en la lista.
                    menuBarManager.folderToEdit = nil
                    menuBarManager.isModalActive = false
                }
                return nil
            }
        }
        guard case .main = menuBarManager.activeViewState, fillingVariablesFor == nil, !isFullScreenImageOpen, !menuBarManager.isModalActive else { return event }
        if keyCode == 36 {
            if selectedPrompt != nil {
                openEditorForSelection()
                return nil
            } else if promptService.selectedCategory != nil {
                openFolderManagerForSelectedCategory()
                return nil
            }
        }
        if modifiers == .command && keyCode == 11 {
            toggleSidebarShortcut()
            return nil
        }
        // Cmd + G: Alternar modo Galería
        if modifiers == .command && keyCode == 5 {
            toggleGridShortcut()
            return nil
        }
        if keyCode == 49 { // Space
            // Si el buscador tiene el foco, dejamos pasar el espacio para que el usuario pueda escribir
            if isSearchFocused { return event }
            // Evita toggles en ráfaga cuando el usuario mantiene presionada la tecla.
            if event.isARepeat { return nil }
            isUserNavigating = false
            
            // Si hay un preview abierto, lo cerramos
            if showingPreview {
                closePreviewImmediately(playSound: true)
                return nil
            }
            
            // Si hay un prompt seleccionado, abrir preview
            if let current = selectedPrompt {
                openPreview(for: current, soundEffect: .preview)
                return nil
            }

            // Fallback: si se perdió la selección, usar el primer resultado visible.
            if let first = promptService.filteredPrompts.first {
                openPreview(for: first, soundEffect: .preview)
                return nil
            }
        }
        if keyCode == 14 && !isSearchFocused { // 'e' key for edit
            if let _ = selectedPrompt {
                if showingPreview {
                    closePreviewImmediately(playSound: false)
                }
                if preferences.soundEnabled { SoundService.shared.playMagicSound() }
                withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                return nil
            }
        }
        if modifiers == .command && keyCode == 8 {
            // Si hay texto seleccionado en el buscador, dejar que el sistema lo copie.
            // Si NO hay selección de texto, copiar el prompt seleccionado en la lista.
            if isSearchFocused && isTextSelectedInSearchField() {
                return event
            }
            if let prompt = selectedPrompt {
                usePrompt(prompt)
                return nil
            }
        }
        if modifiers == .command && keyCode == 51 { // Cmd + Backspace
            if isSearchFocused { return event }
            if let prompt = selectedPrompt {
                deletePrompt(prompt)
                return nil
            }
        }
        if keyCode == 126 { // Up
            guard !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            markUserNavigationActivity()
            isSearchFocused = false
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                // En Grid saltamos de 2 en 2 (filas), en Lista de 1 en 1
                let step = preferences.isGridView ? 2 : 1
                if currentIndex >= step {
                    let nextPrompt = promptService.filteredPrompts[currentIndex - step]
                    applyKeyboardSelectionChange(to: nextPrompt)
                }
            } else if let firstPrompt = promptService.filteredPrompts.first {
                applyKeyboardSelectionChange(to: firstPrompt)
            }
            return nil
        }
        if keyCode == 125 { // Down
            guard !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            markUserNavigationActivity()
            isSearchFocused = false
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                // En Grid saltamos de 2 en 2 (filas), en Lista de 1 en 1
                let step = preferences.isGridView ? 2 : 1
                if currentIndex <= promptService.filteredPrompts.count - (step + 1) {
                    let nextPrompt = promptService.filteredPrompts[currentIndex + step]
                    applyKeyboardSelectionChange(to: nextPrompt)
                }
            } else if let firstPrompt = promptService.filteredPrompts.first {
                applyKeyboardSelectionChange(to: firstPrompt)
            }
            return nil
        }
        if keyCode == 123 { // Left
            guard preferences.isGridView, !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            markUserNavigationActivity()
            isSearchFocused = false
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex > 0 {
                let nextPrompt = promptService.filteredPrompts[currentIndex - 1]
                applyKeyboardSelectionChange(to: nextPrompt)
            }
            return nil
        }
        if keyCode == 124 { // Right
            guard preferences.isGridView, !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            markUserNavigationActivity()
            isSearchFocused = false
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex < promptService.filteredPrompts.count - 1 {
                let nextPrompt = promptService.filteredPrompts[currentIndex + 1]
                applyKeyboardSelectionChange(to: nextPrompt)
            }
            return nil
        }
        if keyCode == 36 || keyCode == 76 { // Enter / Numpad Enter
            if let prompt = selectedPrompt {
                usePrompt(prompt)
                return nil
            }
        }
        return event
    }
    



    
    

    
    
    @ViewBuilder
    private var importOverlays: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.3), lineWidth: isDraggingFile ? 3 : 0).padding(4).allowsHitTesting(false)
            if let msg = importMessage {
                VStack {
                    Spacer()
                    Text(msg).font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundColor(.white).clipShape(Capsule()).padding(.bottom, 20)
                }.transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func handleFileDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let ext = url.pathExtension.lowercased()
                if ext == "zip" {
                    DispatchQueue.main.async {
                        self.importURL = url
                        self.importData = nil
                        self.showingImportAlert = true
                    }
                    return
                }
                if ext == "json", let data = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.importData = data
                        self.importURL = nil
                        self.showingImportAlert = true
                    }
                }
            }
        }
    }

    func latestPrompt(for prompt: Prompt) -> Prompt {
        promptService.promptSnapshot(byId: prompt.id) ?? prompt
    }

    func ensureValidSelection(autoselectFirst: Bool) {
        let visible = promptService.filteredPrompts
        guard !visible.isEmpty else {
            selectedPrompt = nil
            showingPreview = false
            return
        }

        if let current = selectedPrompt,
           let matching = visible.first(where: { $0.id == current.id }) {
            selectedPrompt = latestPrompt(for: matching)
            return
        }

        if autoselectFirst, let first = visible.first {
            selectedPrompt = latestPrompt(for: first)
        }
    }

    func refreshSelectedPromptFromStore() {
        guard let current = selectedPrompt else { return }
        guard let latest = promptService.promptSnapshot(byId: current.id) else {
            selectedPrompt = promptService.filteredPrompts.first.map { latestPrompt(for: $0) }
            showingPreview = false
            return
        }

        let hasDiff =
            latest.modifiedAt != current.modifiedAt ||
            latest.useCount != current.useCount ||
            latest.isFavorite != current.isFavorite ||
            latest.showcaseImageCount != current.showcaseImageCount ||
            latest.showcaseImagePaths != current.showcaseImagePaths ||
            latest.showcaseThumbnails.count != current.showcaseThumbnails.count

        if hasDiff {
            selectedPrompt = latest
        }
    }

    func handleSelectedPromptChanged() {
        guard let selectedPrompt else { return }
        guard showingPreview else { return }

        if isUserNavigating {
            scheduleKeyboardPreviewRefresh(for: selectedPrompt)
            return
        }

        prewarmPreviewAssets(for: selectedPrompt)

        if let firstPrompt = promptService.filteredPrompts.first,
           firstPrompt.id != selectedPrompt.id {
            prewarmSecondaryImageAssets(for: firstPrompt)
        }
    }

    func coordinateSelectionAndPrewarm(forcePrimaryPrewarm: Bool = false) {
        ensureValidSelection(autoselectFirst: false)

        let shouldPrewarm = showingPreview || forcePrimaryPrewarm
        guard shouldPrewarm else { return }

        guard let firstPrompt = promptService.filteredPrompts.first else { return }

        if selectedPrompt == nil || selectedPrompt?.id == firstPrompt.id {
            prewarmPreviewAssets(for: firstPrompt, force: forcePrimaryPrewarm)
        } else {
            prewarmSecondaryImageAssets(for: firstPrompt, force: forcePrimaryPrewarm)
        }

        if let selectedPrompt,
           selectedPrompt.id != firstPrompt.id {
            prewarmPreviewAssets(for: selectedPrompt)
        }
    }

    enum PreviewOpenSound {
        case interaction
        case preview
    }

    func openPreview(for prompt: Prompt, soundEffect: PreviewOpenSound = .interaction) {
        let latest = latestPrompt(for: prompt)

        selectedPrompt = latest
        if !latest.showcaseImagePaths.isEmpty {
            storePreviewPathsInCache(latest.showcaseImagePaths, for: latest.id)
            prefetchedPreviewPromptId = latest.id
            prefetchedPreviewPaths = latest.showcaseImagePaths
        } else if let cached = previewPathsCache[latest.id], !cached.isEmpty {
            prefetchedPreviewPromptId = latest.id
            prefetchedPreviewPaths = cached
        } else {
            prefetchedPreviewPromptId = latest.id
            prefetchedPreviewPaths = []
        }

        showingPreview = true
        if preferences.soundEnabled {
            switch soundEffect {
            case .interaction:
                SoundService.shared.playInteractionSound()
            case .preview:
                SoundService.shared.playPreviewSound()
            }
        }

        if latest.showcaseImageCount > 0 && prefetchedPreviewPaths.isEmpty {
            refreshPreviewPrefetchIfNeeded(for: latest)
        }
    }

    func applyKeyboardSelectionChange(to prompt: Prompt) {
        let latest = latestPrompt(for: prompt)
        selectedPrompt = latest

        if showingPreview {
            scheduleKeyboardPreviewRefresh(for: latest)
            if preferences.soundEnabled {
                SoundService.shared.playPreviewSound()
            }
        }

        HapticService.shared.playLight()
    }




    
    private func scheduleNextGhostTip(initialDelay: Double? = nil) {
        ghostTipTask?.cancel()
        guard preferences.ghostTipsEnabled else { return }
        let delay = initialDelay ?? Double.random(in: 75...135)
        ghostTipTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                if self.menuBarManager.activeViewState == .main && self.preferences.ghostTipsEnabled && self.currentGhostTip == nil {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        let tips = self.ghostTips
                        if !tips.isEmpty {
                            self.currentGhostTip = tips[self.nextTipIndex % tips.count]
                            self.nextTipIndex = (self.nextTipIndex + 1) % tips.count
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 7_500_000_000)
                        if !Task.isCancelled {
                            await MainActor.run {
                                if self.currentGhostTip != nil {
                                    withAnimation(.easeOut(duration: 0.4)) { self.currentGhostTip = nil }
                                }
                            }
                        }
                    }
                }
                if !Task.isCancelled { self.scheduleNextGhostTip() }
            }
        }
    }
    private func handleWindowResize(_ newWidth: CGFloat) {
        let threshold: CGFloat = 565
        guard menuBarManager.activeViewState == .main, !preferences.isGridView else { return }
        
        if newWidth < threshold && preferences.showSidebar {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                preferences.showSidebar = false
            }
        } else if newWidth > threshold && !preferences.showSidebar {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                preferences.showSidebar = true
            }
        }
    }
    
    private func handleDeepLinkNavigation(id: UUID) {
        if let prompt = promptService.prompts.first(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                self.selectedPrompt = prompt
                self.showingPreview = true
                promptService.searchQuery = ""
            }
            HapticService.shared.playSuccess()
        }
        menuBarManager.promptIdToNavigate = nil
    }

    private func isTextSelectedInSearchField() -> Bool {
        guard let window = NSApp.keyWindow,
              let fieldEditor = window.firstResponder as? NSTextView,
              fieldEditor.selectedRange().length > 0 else {
            return false
        }
        return true
    }
}

// MARK: - Guía Visual de Redimensionado HUD
