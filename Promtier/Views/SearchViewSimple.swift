import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
private final class HoverPrewarmCoordinator {
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
    private enum PreviewPrewarmProfile {
        static let maxPixelSize = 1120
    }

    private enum InteractionThrottle {
        static let keyboardRepeatMinInterval: CFTimeInterval = 0.012
    }

    private struct FolderPresentation {
        let color: Color
        let icon: String?
    }

    private enum PromptCopyFormat {
        case plainText
        case markdown
        case richText
        case pack
    }

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    @Environment(\.colorScheme) private var colorScheme
    
    @FocusState private var isSearchFocused: Bool
    @State private var hoverPrewarmCoordinator = HoverPrewarmCoordinator()
    @State private var localEventMonitor: Any?
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var fillingVariablesFor: Prompt?
    @State private var isNavigatingWithKeys: Bool = false
    @State private var showParticles: Bool = false
    @State private var isDraggingFile: Bool = false
    @State private var importMessage: String? = nil
    @State private var showingImportAlert: Bool = false
    @State private var importData: Data? = nil
    @State private var importURL: URL? = nil
    /// Bloquea atajos de teclado cuando hay una hoja/modal secundaria abierta
    @State private var isFullScreenImageOpen: Bool = false
    // Prewarm de preview/texto para evitar beachball al abrir preview tras arrancar.
    @State private var prewarmTask: Task<Void, Never>? = nil
    @State private var secondaryImagePrewarmTask: Task<Void, Never>? = nil
    @State private var delayedPrewarmTask: Task<Void, Never>? = nil
    @State private var previewPrefetchTask: Task<Void, Never>? = nil
    @State private var lastPrewarmedPreviewKey: String? = nil
    @State private var lastSecondaryImagePrewarmKey: String? = nil
    @State private var prefetchedPreviewPaths: [String] = []
    @State private var prefetchedPreviewPromptId: UUID? = nil
    @State private var previewPathsCache: [UUID: [String]] = [:]
    @State private var previewCacheOrder: [UUID] = []
    @State private var lastKeyboardNavigationTimestamp: CFTimeInterval = 0
    
    @State private var dragStartedSidebarWidth: CGFloat = 0
    @State private var isSidebarDragging: Bool = false
    
    @State private var isPlusHovered = false
    @State private var isBatchHovered = false
    @State private var isSettingsHovered = false
    @State private var isViewToggleHovered = false
    @State private var isSidebarResizerHovered = false
    
    // Ghost Tips logic
    private var selectedPromptCategoryColor: Color {
        guard let p = selectedPrompt, let folderName = p.folder else {
            return .blue // Fallback
        }
        if let folder = promptService.folders.first(where: { $0.name == folderName }) {
            return Color(hex: folder.displayColor)
        }
        return .blue
    }
    
    @State private var currentGhostTip: GhostTip? = nil
    @State private var nextTipIndex: Int = 0
    @State private var isGhostTipSuppressedByClipboard = false
    @State private var ghostTipTask: Task<Void, Never>? = nil
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
            GhostTip(title: "AI Quick Draft", icon: "sparkles", shortcut: preferences.shortcutDisplayString(keyCode: preferences.aiDraftHotkeyCode, modifiers: preferences.aiDraftHotkeyModifiers)),
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
            GhostTip(title: "gt_auto_paste_tip".localized(for: preferences.language), icon: "wand.and.stars", shortcut: "gt_auto_paste_shortcut".localized(for: preferences.language)),
             GhostTip(title: "gt_drag_images".localized(for: preferences.language), icon: "photo", shortcut: "gt_images_hint".localized(for: preferences.language)),
            GhostTip(title: "gt_zoom_images".localized(for: preferences.language), icon: "magnifyingglass", shortcut: "gt_zoom_hint".localized(for: preferences.language))
        ]
    }

    private var folderPresentationByName: [String: FolderPresentation] {
        Dictionary(uniqueKeysWithValues: promptService.folders.map {
            ($0.name, FolderPresentation(color: Color(hex: $0.displayColor), icon: $0.icon))
        })
    }
    
    var body: some View {
        ZStack {
            switch menuBarManager.activeViewState {
            case .main:
                mainView
                    .overlay(alignment: .bottom) {
                        if let suggestedContent = menuBarManager.suggestedClipboardContent {
                            ClipboardSuggestionBanner(content: suggestedContent)
                                .padding(.bottom, 32) // Más arriba para evitar solapamiento sutil
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                                .zIndex(70)
                        }
                    }
                    .transition(.opacity)
            case .newPrompt:
                NewPromptView(prompt: selectedPrompt, onClose: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPrompt = nil
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
            let threshold: CGFloat = 565
            
            // Solo auto-ocultar/mostrar en la vista principal
            guard menuBarManager.activeViewState == .main, !preferences.isGridView else { return }
            
            if newWidth < threshold && preferences.showSidebar {
                // Auto-hide when shrinking past 565
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    preferences.showSidebar = false
                }
            } else if newWidth > threshold && !preferences.showSidebar {
                // Auto-show when expanding past 565
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    preferences.showSidebar = true
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PromtierCustomShortcutPressed"))) { notification in
            guard let promptId = notification.object as? UUID,
                  let prompt = promptService.prompts.first(where: { $0.id == promptId }) else { return }
            
            if prompt.hasTemplateVariables() {
                menuBarManager.showPopover()
                // Dar tiempo a que el popover se muestre antes de activar el overlay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    usePrompt(prompt)
                }
            } else {
                // Copia silenciosa en background sin abrir ventana si no hay variables
                usePrompt(prompt)
            }
        }
    }
    
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
                            // Hit area profesional: exactamente en el borde, cursor inmediato
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 6)
                                .contentShape(Rectangle())
                                .offset(x: 3) // sobresale 3px hacia el contenido para quedar centrado en la línea divisoria
                                .onHover { inside in
                                    isSidebarResizerHovered = inside
                                    if inside {
                                        NSCursor.resizeLeftRight.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                    menuBarManager.setSidebarHovered(inside)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                        .onChanged { value in
                                            if !isSidebarDragging {
                                                isSidebarDragging = true
                                                dragStartedSidebarWidth = preferences.sidebarWidth
                                                // Ensure cursor doesn't reset when dragging fast
                                            }
                                            let proposed = dragStartedSidebarWidth + value.translation.width
                                            preferences.sidebarWidth = min(300, max(201, proposed))
                                        }
                                        .onEnded { _ in
                                            isSidebarDragging = false
                                            dragStartedSidebarWidth = 0
                                        }
                                )
                        }
                }
                
                // Contenido principal
                VStack(spacing: 0) {
                    // Banner de Accesibilidad (Refinado)
                    if !ShortcutManager.shared.isAccessibilityGranted {
                        AccessibilityBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(50)
                    }
                    
                    searchHeaderView
                    
                    Divider().padding(.leading, 14).padding(.trailing, 24)
                    
                    promptContentView
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

    private var searchHeaderView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        preferences.isGridView.toggle()
                        if preferences.autoHideSidebarInGallery {
                            preferences.showSidebar = !preferences.isGridView
                        }
                    }
                }) {
                    Image(systemName: preferences.isGridView ? "list.dash.header.rectangle" : "text.below.photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(preferences.isGridView ? .blue : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(preferences.isGridView ? Color.blue.opacity(isViewToggleHovered ? 0.15 : 0.1) : Color.primary.opacity(isViewToggleHovered ? 0.08 : 0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(preferences.isGridView ? Color.blue.opacity(isViewToggleHovered ? 0.3 : 0.15) : Color.primary.opacity(isViewToggleHovered ? 0.12 : 0.06), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isViewToggleHovered = hovering
                }
                .help(preferences.isGridView ? "List View" : "Grid View")

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)

                    TextField("search_placeholder".localized(for: preferences.language), text: $promptService.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15 * preferences.fontSize.scale))
                        .disableAutocorrection(true)
                        .focused($isSearchFocused)
                        .onExitCommand {
                            isSearchFocused = false
                        }
                        .onChange(of: promptService.searchQuery) { _, newValue in
                            isNavigatingWithKeys = false
                            if newValue.count > 40 {
                                promptService.searchQuery = String(newValue.prefix(40))
                            }
                        }

                    if !promptService.searchQuery.isEmpty {
                        Button(action: { promptService.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPrompt = nil
                            menuBarManager.activeViewState = .newPrompt
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isPlusHovered ? Color.blue.opacity(0.85) : Color.blue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(isPlusHovered ? 0.2 : 0), lineWidth: 1)
                                    )
                                    .shadow(color: preferences.isHaloEffectEnabled ? Color.blue.opacity(isPlusHovered ? 0.4 : 0.3) : .clear, radius: isPlusHovered ? 6 : 4, y: 2)
                            )
                            .scaleEffect(isPlusHovered ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPlusHovered = hovering
                        }
                    }
                    .help("new_prompt".localized(for: preferences.language) + " (N)")

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            batchService.isSelectionModeActive.toggle()
                            if !batchService.isSelectionModeActive {
                                batchService.clearSelection()
                            }
                        }
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: batchService.isSelectionModeActive ? "checkmark.circle.fill" : "list.bullet.indent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(batchService.isSelectionModeActive ? .blue : .primary.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(batchService.isSelectionModeActive ? Color.blue.opacity(0.12) : Color.primary.opacity(isBatchHovered ? 0.08 : 0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(batchService.isSelectionModeActive ? Color.blue.opacity(0.3) : Color.primary.opacity(isBatchHovered ? 0.12 : 0.06), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isBatchHovered = hovering
                    }
                    .help(batchService.isSelectionModeActive ? "cancel_selection_help".localized(for: preferences.language) : "batch_selection_help".localized(for: preferences.language))

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            menuBarManager.activeViewState = .preferences
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(isSettingsHovered ? 0.08 : 0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.primary.opacity(isSettingsHovered ? 0.12 : 0.06), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isSettingsHovered = hovering
                    }
                    .help("settings".localized(for: preferences.language) + " (Cmd+,)")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onTapGesture {
            isSearchFocused = false
        }
    }

    @ViewBuilder
    private var promptContentView: some View {
        if promptService.filteredPrompts.isEmpty {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "text.bubble")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.6))

                VStack(spacing: 12) {
                    Text(promptService.searchQuery.isEmpty ? "no_prompts".localized(for: preferences.language) : "no_results".localized(for: preferences.language))
                        .font(.system(size: 20 * preferences.fontSize.scale, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(promptService.searchQuery.isEmpty ? "create_first_prompt".localized(for: preferences.language) : "try_other_terms".localized(for: preferences.language))
                        .font(.system(size: 14 * preferences.fontSize.scale))
                        .foregroundColor(.secondary)
                }

                if promptService.searchQuery.isEmpty {
                    Button("create_first_prompt".localized(for: preferences.language)) {
                        selectedPrompt = nil
                        withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 14)
            .padding(.trailing, 24)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    if preferences.isGridView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16) {
                            ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                promptGridCard(for: prompt)
                                    .id(prompt.id)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .padding(.vertical, 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                promptRow(for: prompt)
                                    .id(prompt.id)
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.trailing, 14)
                        .padding(.vertical, 16)
                    }
                }
                .scrollIndicators(.hidden)
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = false
                }
                .onChange(of: selectedPrompt?.id) { _, newId in
                    guard let id = newId, isNavigatingWithKeys else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func categoryColor(for prompt: Prompt) -> Color {
        guard let folderName = prompt.folder, !folderName.isEmpty else { return .blue }
        if let folder = folderPresentationByName[folderName] {
            return folder.color
        }
        return PredefinedCategory.fromString(folderName)?.color ?? .blue
    }

    private func resolvedIcon(for prompt: Prompt) -> String {
        if let customIcon = prompt.icon, !customIcon.isEmpty {
            return customIcon
        }
        guard let folderName = prompt.folder, !folderName.isEmpty else {
            return "doc.text.fill"
        }
        if let folder = folderPresentationByName[folderName] {
            return folder.icon ?? "folder.fill"
        }
        return PredefinedCategory.fromString(folderName)?.icon ?? "folder.fill"
    }

    private func handlePromptHover(_ prompt: Prompt, isHovering: Bool) {
        hoverPrewarmCoordinator.handleHover(prompt: prompt, isHovering: isHovering) { hoveredPrompt in
            let latest = latestPrompt(for: hoveredPrompt)
            prewarmPreviewAssets(for: latest)
        }
    }

    private func selectedPreviewPopoverBinding(for promptId: UUID) -> Binding<Bool> {
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

    private func closePreviewImmediately(playSound: Bool) {
        guard showingPreview else { return }

        previewPrefetchTask?.cancel()
        prewarmTask?.cancel()
        secondaryImagePrewarmTask?.cancel()
        hoverPrewarmCoordinator.cancelAll()

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

    private func openEditorForSelection() {
        guard selectedPrompt != nil else { return }
        withAnimation(.spring()) {
            menuBarManager.activeViewState = .newPrompt
        }
    }

    private func openFolderManagerForSelectedCategory() {
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
        guard event.isARepeat else { return false }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastKeyboardNavigationTimestamp < InteractionThrottle.keyboardRepeatMinInterval {
            return true
        }

        lastKeyboardNavigationTimestamp = now
        return false
    }

    @ViewBuilder
    private func previewPopoverIfSelected<Content: View>(for prompt: Prompt, @ViewBuilder content: () -> Content) -> some View {
        if showingPreview && selectedPrompt?.id == prompt.id {
            content()
                .popover(isPresented: selectedPreviewPopoverBinding(for: prompt.id), arrowEdge: .top) {
                    PromptPreviewView(
                        prompt: selectedPrompt ?? prompt,
                        prefetchedShowcasePaths: (prefetchedPreviewPromptId == prompt.id) ? prefetchedPreviewPaths : nil,
                        isFullScreenImageOpen: $isFullScreenImageOpen,
                        onUse: { usePrompt(prompt) }
                    )
                }
        } else {
            content()
        }
    }

    @ViewBuilder
    private func promptGridCard(for prompt: Prompt) -> some View {
        let categoryColor = categoryColor(for: prompt)
        previewPopoverIfSelected(for: prompt) {
            PromptGridCard(
                prompt: prompt,
                precomputedCategoryColor: categoryColor,
                isSelected: selectedPrompt?.id == prompt.id,
                isHovered: false,
                onTap: {
                    isSearchFocused = false
                    isNavigatingWithKeys = false
                    let latest = latestPrompt(for: prompt)
                    selectedPrompt = latest
                    prewarmPreviewAssets(for: latest)
                    if showingPreview { refreshPreviewPrefetchIfNeeded(for: latest) }
                    if showingPreview && preferences.soundEnabled {
                        SoundService.shared.playInteractionSound()
                    }
                    NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                },
                onDoubleTap: {
                    isNavigatingWithKeys = false
                    selectedPrompt = latestPrompt(for: prompt)
                    withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                },
                onCopy: { usePrompt(prompt) },
                onHover: { isHovering in
                    handlePromptHover(prompt, isHovering: isHovering)
                }
            )
            .contextMenu { promptContextMenu(for: prompt) }
        }
    }

    @ViewBuilder
    private func promptRow(for prompt: Prompt) -> some View {
        let categoryColor = categoryColor(for: prompt)
        let icon = resolvedIcon(for: prompt)
        previewPopoverIfSelected(for: prompt) {
            PromptCard(
                prompt: prompt,
                precomputedCategoryColor: categoryColor,
                precomputedResolvedIcon: icon,
                isSelected: selectedPrompt?.id == prompt.id,
                isHovered: false,
                onTap: {
                    isSearchFocused = false
                    isNavigatingWithKeys = false
                    let latest = latestPrompt(for: prompt)
                    selectedPrompt = latest
                    prewarmPreviewAssets(for: latest)
                    if showingPreview { refreshPreviewPrefetchIfNeeded(for: latest) }
                    if showingPreview && preferences.soundEnabled {
                        SoundService.shared.playInteractionSound()
                    }
                    NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                },
                onDoubleTap: {
                    isNavigatingWithKeys = false
                    selectedPrompt = latestPrompt(for: prompt)
                    withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                },
                onCopy: { usePrompt(prompt) },
                onCopyPack: { copyPromptPack(prompt) },
                onHover: { isHovering in
                    handlePromptHover(prompt, isHovering: isHovering)
                }
            )
            .contextMenu { promptContextMenu(for: prompt) }
        }
    }

    @ViewBuilder
    private func promptContextMenu(for prompt: Prompt) -> some View {
        Button(action: { usePrompt(prompt) }) {
            Label("copy".localized(for: preferences.language), systemImage: "doc.on.doc")
        }
        Menu {
            Button("Plain Text") { copyPrompt(prompt, as: .plainText) }
            Button("Markdown") { copyPrompt(prompt, as: .markdown) }
            Button("Rich Text") { copyPrompt(prompt, as: .richText) }
            Divider()
            Button("Copy Pack") { copyPrompt(prompt, as: .pack) }
        } label: {
            Label("Copy As…", systemImage: "doc.on.clipboard")
        }
        Button(action: {
            FloatingAIDraftManager.shared.show(content: prompt.content)
            if preferences.soundEnabled { SoundService.shared.playMagicSound() }
        }) {
            Label("AI Draft / Refine", systemImage: "sparkles")
        }
        Button(action: {
            selectedPrompt = latestPrompt(for: prompt)
            if preferences.soundEnabled { SoundService.shared.playMagicSound() }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
        }
        Button(action: {
            openPreview(for: prompt)
        }) {
            Label("preview".localized(for: preferences.language), systemImage: "eye")
        }
        Button(action: { toggleFavorite(prompt) }) {
            Label(
                prompt.isFavorite ? "remove_favorite".localized(for: preferences.language) : "add_favorite".localized(for: preferences.language),
                systemImage: prompt.isFavorite ? "star.slash" : "star.fill"
            )
        }
        Divider()
        // Acciones rápidas de configuración
        Button(action: {
            selectedPrompt = latestPrompt(for: prompt)
            if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("Asignar Atajo", systemImage: "command.circle")
        }
        Button(action: {
            selectedPrompt = latestPrompt(for: prompt)
            if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("Asignar App", systemImage: "app.badge")
        }
        Divider()
        Button(action: {
            if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
            exportPromptsToFile(prompt)
        }) {
            Label("export_plain_text".localized(for: preferences.language), systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: { deletePrompt(prompt) }) {
            Label("delete".localized(for: preferences.language), systemImage: "trash.fill")
        }
    }
    
    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
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
        if keyCode == 14 { // 'e' key for edit
            if showingPreview, let _ = selectedPrompt {
                closePreviewImmediately(playSound: false)
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
            isNavigatingWithKeys = true
            isSearchFocused = false
            let playFeedback = !event.isARepeat
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                // En Grid saltamos de 2 en 2 (filas), en Lista de 1 en 1
                let step = preferences.isGridView ? 2 : 1
                if currentIndex >= step {
                    let nextPrompt = promptService.filteredPrompts[currentIndex - step]
                    applyKeyboardSelectionChange(to: nextPrompt, playFeedback: playFeedback)
                }
            } else if let firstPrompt = promptService.filteredPrompts.first {
                applyKeyboardSelectionChange(to: firstPrompt, playFeedback: playFeedback)
            }
            return nil
        }
        if keyCode == 125 { // Down
            guard !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            isNavigatingWithKeys = true
            isSearchFocused = false
            let playFeedback = !event.isARepeat
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                // En Grid saltamos de 2 en 2 (filas), en Lista de 1 en 1
                let step = preferences.isGridView ? 2 : 1
                if currentIndex <= promptService.filteredPrompts.count - (step + 1) {
                    let nextPrompt = promptService.filteredPrompts[currentIndex + step]
                    applyKeyboardSelectionChange(to: nextPrompt, playFeedback: playFeedback)
                }
            } else if let firstPrompt = promptService.filteredPrompts.first {
                applyKeyboardSelectionChange(to: firstPrompt, playFeedback: playFeedback)
            }
            return nil
        }
        if keyCode == 123 { // Left
            guard preferences.isGridView, !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            isNavigatingWithKeys = true
            isSearchFocused = false
            let playFeedback = !event.isARepeat
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex > 0 {
                let nextPrompt = promptService.filteredPrompts[currentIndex - 1]
                applyKeyboardSelectionChange(to: nextPrompt, playFeedback: playFeedback)
            }
            return nil
        }
        if keyCode == 124 { // Right
            guard preferences.isGridView, !promptService.filteredPrompts.isEmpty else { return event }
            if shouldThrottleKeyboardNavigation(for: event) { return nil }
            isNavigatingWithKeys = true
            isSearchFocused = false
            let playFeedback = !event.isARepeat
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex < promptService.filteredPrompts.count - 1 {
                let nextPrompt = promptService.filteredPrompts[currentIndex + 1]
                applyKeyboardSelectionChange(to: nextPrompt, playFeedback: playFeedback)
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
    
    private func usePrompt(_ prompt: Prompt) {
        if prompt.hasTemplateVariables() || prompt.hasChains() {
            if prompt.isSmartOnly() && !prompt.hasChains() {
                let resolvedContent = PlaceholderResolver.shared.resolveAll(in: prompt.content)
                self.promptService.usePrompt(prompt, contentOverride: resolvedContent)
            } else {
                closePreviewImmediately(playSound: false)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { fillingVariablesFor = prompt }
                return
            }
        } else {
            self.promptService.usePrompt(prompt)
        }
        if self.preferences.soundEnabled { SoundService.shared.playCopySound() }
        HapticService.shared.playAlignment()
        if self.preferences.isPremiumActive && self.preferences.visualEffectsEnabled {
            self.showParticles = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.showParticles = true }
        }
        closePreviewImmediately(playSound: false)
        if self.preferences.closeOnCopy {
            if self.preferences.isPremiumActive && self.preferences.visualEffectsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.menuBarManager.closePopover() }
            } else {
                self.menuBarManager.closePopover()
            }
        }
    }

    private func copyPromptPack(_ prompt: Prompt) {
        copyPrompt(prompt, as: .pack)
    }

    private func copyPrompt(_ prompt: Prompt, as format: PromptCopyFormat) {
        let markdownContent: String
        switch format {
        case .pack:
            markdownContent = promptPackMarkdown(for: prompt)
        case .markdown, .plainText, .richText:
            markdownContent = prompt.content
        }

        switch format {
        case .markdown, .pack:
            ClipboardService.shared.copyToClipboard(markdownContent)
        case .plainText:
            let plainText = MarkdownRTFConverter.parseMarkdown(
                markdownContent,
                baseFont: .systemFont(ofSize: 14),
                textColor: .labelColor
            ).string
            ClipboardService.shared.copyToClipboard(plainText)
        case .richText:
            let attributed = MarkdownRTFConverter.parseMarkdown(
                markdownContent,
                baseFont: .systemFont(ofSize: 14),
                textColor: .labelColor
            )
            ClipboardService.shared.copyRichTextToClipboard(attributed)
        }

        promptService.recordPromptUse(prompt)
        if preferences.soundEnabled { SoundService.shared.playCopySound() }
        HapticService.shared.playAlignment()
        if preferences.isPremiumActive && preferences.visualEffectsEnabled {
            showParticles = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { showParticles = true }
        }
        closePreviewImmediately(playSound: false)
        if preferences.closeOnCopy {
            if preferences.isPremiumActive && preferences.visualEffectsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { menuBarManager.closePopover() }
            } else {
                menuBarManager.closePopover()
            }
        }
    }

    private func promptPackMarkdown(for prompt: Prompt) -> String {
        var parts: [String] = [prompt.content]
        if let negative = prompt.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !negative.isEmpty {
            let title = "negative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(negative)")
        }
        for (index, alt) in prompt.alternatives.enumerated() {
            let trimmed = alt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let title = "\("alternative".localized(for: preferences.language)) #\(index + 1)"
                parts.append("\n\n\(title):\n\(trimmed)")
            }
        }
        if prompt.alternatives.isEmpty, let alternative = prompt.alternativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !alternative.isEmpty {
            let title = "alternative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(alternative)")
        }
        return parts.joined()
    }
    
    private func toggleFavorite(_ prompt: Prompt) {
        var updatedPrompt = latestPrompt(for: prompt)
        updatedPrompt.isFavorite.toggle()
        _ = self.promptService.updatePrompt(updatedPrompt)
        if selectedPrompt?.id == updatedPrompt.id {
            selectedPrompt = updatedPrompt
        }
        if self.preferences.soundEnabled { SoundService.shared.playFavoriteSound() }
        HapticService.shared.playImpact()
    }
    
    private func deletePrompt(_ prompt: Prompt) {
        if batchService.isSelectionModeActive, batchService.selectedPromptIds.contains(prompt.id), batchService.selectedPromptIds.count > 1 {
            _ = promptService.deletePrompts(withIds: Array(batchService.selectedPromptIds))
            withAnimation(.spring()) { batchService.clearSelection() }
        } else {
            _ = self.promptService.deletePrompt(prompt)
            if batchService.isSelectionModeActive { batchService.selectedPromptIds.remove(prompt.id) }
        }
        if self.preferences.soundEnabled { SoundService.shared.playDeleteSound() }
    }

    private func forkPrompt(_ prompt: Prompt) {
        closePreviewImmediately(playSound: false)
        menuBarManager.showWithState(.newPrompt)
        
        var forkedPrompt = prompt
        forkedPrompt.id = UUID() // New ID
        forkedPrompt.title = prompt.title + " (Copy)"
        forkedPrompt.createdAt = Date()
        forkedPrompt.modifiedAt = Date()
        forkedPrompt.useCount = 0
        forkedPrompt.lastUsedAt = nil
        forkedPrompt.isFavorite = false
        
        DraftService.shared.saveDraft(prompt: forkedPrompt, isEditing: false)
    }
    
    private func exportPromptsToFile(_ prompt: Prompt) {
        let exportContent = "\(prompt.title)\n\n\(prompt.content)"
        let fileName = "\(prompt.title.replacingOccurrences(of: " ", with: "_")).txt"
        let savePanel = NSSavePanel()
        if let txtType = UTType(filenameExtension: "txt") { savePanel.allowedContentTypes = [txtType, .plainText] }
        else { savePanel.allowedContentTypes = [.plainText] }
        savePanel.nameFieldStringValue = fileName
        savePanel.title = "export_prompts_title".localized(for: preferences.language)
        savePanel.message = "export_prompts_message".localized(for: preferences.language)
        NSApp.activate(ignoringOtherApps: true)
        self.menuBarManager.closePopover()
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do { try exportContent.write(to: url, atomically: true, encoding: .utf8) }
                catch {
                    let alert = NSAlert()
                    alert.messageText = "export_error_title".localized(for: preferences.language)
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
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

    private func latestPrompt(for prompt: Prompt) -> Prompt {
        promptService.promptSnapshot(byId: prompt.id) ?? prompt
    }

    private func ensureValidSelection(autoselectFirst: Bool) {
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

    private func refreshSelectedPromptFromStore() {
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

    private func handleSelectedPromptChanged() {
        guard let selectedPrompt else { return }
        guard showingPreview else { return }
        prewarmPreviewAssets(for: selectedPrompt)

        if let firstPrompt = promptService.filteredPrompts.first,
           firstPrompt.id != selectedPrompt.id {
            prewarmSecondaryImageAssets(for: firstPrompt)
        }
    }

    private func coordinateSelectionAndPrewarm(forcePrimaryPrewarm: Bool = false) {
        ensureValidSelection(autoselectFirst: true)

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

    private enum PreviewOpenSound {
        case interaction
        case preview
    }

    @MainActor
    private func cachedPreviewPaths(for promptId: UUID) -> [String]? {
        previewPathsCache[promptId]
    }

    @MainActor
    private func storePreviewPathsInCache(_ paths: [String], for promptId: UUID) {
        guard !paths.isEmpty else { return }

        if let existingIndex = previewCacheOrder.firstIndex(of: promptId) {
            previewCacheOrder.remove(at: existingIndex)
        }
        previewCacheOrder.append(promptId)

        previewPathsCache[promptId] = paths

        let maxCacheEntries = 160
        if previewCacheOrder.count > maxCacheEntries {
            let overflow = previewCacheOrder.count - maxCacheEntries
            let evicted = previewCacheOrder.prefix(overflow)
            for id in evicted {
                previewPathsCache.removeValue(forKey: id)
            }
            previewCacheOrder.removeFirst(overflow)
        }
    }

    private func loadPreviewPaths(for prompt: Prompt) async -> [String] {
        if !prompt.showcaseImagePaths.isEmpty {
            await MainActor.run {
                storePreviewPathsInCache(prompt.showcaseImagePaths, for: prompt.id)
            }
            return prompt.showcaseImagePaths
        }

        if let cached = await MainActor.run(body: { cachedPreviewPaths(for: prompt.id) }), !cached.isEmpty {
            return cached
        }

        guard prompt.showcaseImageCount > 0 else { return [] }

        let fetched = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
        if !fetched.isEmpty {
            await MainActor.run {
                storePreviewPathsInCache(fetched, for: prompt.id)
            }
        }
        return fetched
    }

    private func refreshPreviewPrefetchIfNeeded(for prompt: Prompt) {
        let latest = latestPrompt(for: prompt)

        if !latest.showcaseImagePaths.isEmpty {
            storePreviewPathsInCache(latest.showcaseImagePaths, for: latest.id)
            prefetchedPreviewPromptId = latest.id
            prefetchedPreviewPaths = latest.showcaseImagePaths
            return
        }

        if let cached = previewPathsCache[latest.id], !cached.isEmpty {
            prefetchedPreviewPromptId = latest.id
            prefetchedPreviewPaths = cached
            return
        }

        if prefetchedPreviewPromptId == latest.id && !prefetchedPreviewPaths.isEmpty {
            return
        }

        previewPrefetchTask?.cancel()
        previewPrefetchTask = Task(priority: .userInitiated) {
            let paths = await loadPreviewPaths(for: latest)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard selectedPrompt?.id == latest.id else { return }
                prefetchedPreviewPromptId = latest.id
                prefetchedPreviewPaths = paths
                if !paths.isEmpty {
                    previewPathsCache[latest.id] = paths
                }
            }
        }
    }

    private func openPreview(for prompt: Prompt, soundEffect: PreviewOpenSound = .interaction) {
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

    private func applyKeyboardSelectionChange(to prompt: Prompt, playFeedback: Bool) {
        let latest = latestPrompt(for: prompt)
        selectedPrompt = latest

        if showingPreview {
            refreshPreviewPrefetchIfNeeded(for: latest)
            if playFeedback && preferences.soundEnabled {
                SoundService.shared.playInteractionSound()
            }
        }

        if playFeedback {
            HapticService.shared.playLight()
        }
    }

    private func prewarmPreviewAssets(for prompt: Prompt, force: Bool = false) {
        let previewKey = "\(prompt.id.uuidString):\(Int(preferences.fontSize.scale * 100)):\(prompt.modifiedAt.timeIntervalSince1970)"
        if !force && lastPrewarmedPreviewKey == previewKey { return }
        lastPrewarmedPreviewKey = previewKey
        prewarmTask?.cancel()

        let scale = preferences.fontSize.scale
        let themeColor = previewThemeColor(for: prompt)
        let interfaceStyle = previewInterfaceStyle
        prewarmTask = Task(priority: .utility) {
            // Prewarm del texto en background (evita trabajo pesado en el primer preview).
            _ = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let prewarmedText = PromptPreviewTextCache.shared.highlightedString(
                        for: prompt,
                        themeColor: themeColor,
                        scale: scale,
                        interfaceStyle: interfaceStyle
                    )
                    continuation.resume(returning: prewarmedText)
                }
            }

            if prompt.showcaseImageCount > 0 {
                var paths = prompt.showcaseImagePaths
                if paths.isEmpty,
                   let cached = await MainActor.run(body: { cachedPreviewPaths(for: prompt.id) }),
                   !cached.isEmpty {
                    paths = cached
                }
                if paths.isEmpty {
                    paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
                }
                if !paths.isEmpty {
                    await MainActor.run {
                        storePreviewPathsInCache(paths, for: prompt.id)
                    }
                }

                for (index, relativePath) in paths.prefix(2).enumerated() {
                    let url = ImageStore.shared.url(forRelativePath: relativePath)
                    let cacheKey = "\(prompt.id.uuidString):preview:\(index):\(PreviewPrewarmProfile.maxPixelSize):\(relativePath)"
                    await ImageDecodeThrottler.prewarm(
                        url: url,
                        cacheKey: cacheKey,
                        maxPixelSize: PreviewPrewarmProfile.maxPixelSize
                    )
                }
            }
        }
    }

    private func prewarmSecondaryImageAssets(for prompt: Prompt, force: Bool = false) {
        let key = "secondary:\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970)"
        if !force && lastSecondaryImagePrewarmKey == key { return }
        lastSecondaryImagePrewarmKey = key

        secondaryImagePrewarmTask?.cancel()
        secondaryImagePrewarmTask = Task(priority: .utility) {
            var paths = prompt.showcaseImagePaths

            if paths.isEmpty,
               let cached = await MainActor.run(body: { cachedPreviewPaths(for: prompt.id) }),
               !cached.isEmpty {
                paths = cached
            }

            if paths.isEmpty, prompt.showcaseImageCount > 0 {
                paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            }

            guard !Task.isCancelled else { return }
            guard !paths.isEmpty else { return }

            await MainActor.run {
                storePreviewPathsInCache(paths, for: prompt.id)
            }

            for (index, relativePath) in paths.prefix(2).enumerated() {
                guard !Task.isCancelled else { return }
                let url = ImageStore.shared.url(forRelativePath: relativePath)
                let cacheKey = "\(prompt.id.uuidString):preview:\(index):\(PreviewPrewarmProfile.maxPixelSize):\(relativePath)"
                await ImageDecodeThrottler.prewarm(
                    url: url,
                    cacheKey: cacheKey,
                    maxPixelSize: PreviewPrewarmProfile.maxPixelSize
                )
            }
        }
    }

    private func previewThemeColor(for prompt: Prompt) -> PromptPreviewThemeColor {
        if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
            return PromptPreviewThemeColor(NSColor(category.color))
        }
        return PromptPreviewThemeColor(.systemBlue)
    }

    private var previewInterfaceStyle: PromptPreviewInterfaceStyle {
        colorScheme == .dark ? .dark : .light
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
