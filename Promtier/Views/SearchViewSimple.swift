import SwiftUI
import AppKit
import UniformTypeIdentifiers

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
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
    @State private var localEventMonitor: Any?
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
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
    @State private var delayedPrewarmTask: Task<Void, Never>? = nil
    @State private var lastPrewarmedPreviewKey: String? = nil
    
    @State private var dragStartedSidebarWidth: CGFloat = 0
    
    @State private var isPlusHovered = false
    @State private var isBatchHovered = false
    @State private var isSettingsHovered = false
    @State private var isViewToggleHovered = false
    
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
            
            // Atajos Personalizables (Globales)
            GhostTip(title: "gt_fast_add_title".localized(for: preferences.language), icon: "bolt.fill", shortcut: preferences.shortcutDisplayString(keyCode: preferences.fastAddHotkeyCode, modifiers: preferences.fastAddHotkeyModifiers)),
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
        .frame(width: preferences.windowWidth, height: preferences.windowHeight)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
            
            // Programar primer Ghost Tip si están activados (Triplicado)
            if preferences.ghostTipsEnabled {
                scheduleNextGhostTip(initialDelay: 9.0)
            }
            
            if localEventMonitor == nil {
                localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    return handleLocalKeyEvent(event)
                }
            }
            delayedPrewarmTask?.cancel()
            if let firstPrompt = promptService.filteredPrompts.first {
                delayedPrewarmTask = Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    await MainActor.run {
                        prewarmPreviewAssets(for: firstPrompt, force: true)
                    }
                }
            }
        }
        .onDisappear {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
            prewarmTask?.cancel()
            delayedPrewarmTask?.cancel()
        }
        .onChange(of: selectedPrompt?.id) { _, _ in
            guard let selectedPrompt else { return }
            prewarmPreviewAssets(for: selectedPrompt)
        }
        .onChange(of: promptService.filteredPrompts.first?.id) { _, newValue in
            guard selectedPrompt == nil,
                  let newValue,
                  let firstPrompt = promptService.filteredPrompts.first(where: { $0.id == newValue }) else { return }
            prewarmPreviewAssets(for: firstPrompt, force: true)
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
                            // Hit area invisible para redimensionar (15px al borde)
                            Rectangle()
                                .fill(Color.white.opacity(0.001))
                                .frame(width: 15)
                                .onHover { inside in
                                    if inside { NSCursor.resizeLeftRight.push() }
                                    else { NSCursor.pop() }
                                    
                                    // Sincronizar hover con la sidebar para el botón de categorías (con retraso al salir)
                                    menuBarManager.setSidebarHovered(inside)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("sidebarContainer"))
                                        .onChanged { value in
                                            // Usamos la posición absoluta del mouse en el contenedor nombrado
                                            let newWidth = value.location.x
                                            if newWidth >= 200 && newWidth <= 350 {
                                                preferences.sidebarWidth = newWidth
                                            }
                                        }
                                )
                        }
                }
                
                // Contenido principal
                VStack(spacing: 0) {
                    // Banner de Accesibilidad (Refinado)
                    if !ShortcutManager.shared.isAccessibilityGranted && !preferences.suppressAccessibilityWarning {
                        AccessibilityBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(50)
                    }
                    
                    // Header Premium con búsqueda
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // Botón Colapsar Sidebar / Cambiar a Grid
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        preferences.isGridView.toggle()
                                        preferences.showSidebar = !preferences.isGridView
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
                            
                            // Buscador Estilizado
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
                                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            
                            // Acciones rápidas
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
                                
                                // Botón de AI Draft (Abre panel tipo Fast Add para borradores rápidos AI)
                                Button(action: {
                                    FloatingAIDraftManager.shared.show()
                                    HapticService.shared.playLight()
                                }) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.purple)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.purple.opacity(0.12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("AI Quick Draft (Cmd+Shift+I)")
                                
                                // Botón de Selección en Lote
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
                        .padding(.leading, 22)
                        .padding(.trailing, 24)
                        .padding(.vertical, 20)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .onTapGesture {
                        isSearchFocused = false
                    }
                    
                    Divider().padding(.leading, 22).padding(.trailing, 24)
                    
                    // Contenido principal
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
                        .padding(.leading, 22)
                        .padding(.trailing, 24)
                    } else {
                        // Lista moderna o Grid de prompts
                        ScrollViewReader { proxy in
                            ScrollView {
                                if preferences.isGridView {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16) {
                                        ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                            promptGridCard(for: prompt)
                                                .id(prompt.id)
                                        }
                                    }
                                    .padding(.leading, 22)
                                    .padding(.trailing, 24)
                                    .padding(.vertical, 16)
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                            promptRow(for: prompt)
                                                .id(prompt.id)
                                        }
                                    }
                                    .padding(.leading, 22)
                                    .padding(.trailing, 24)
                                    .padding(.vertical, 16)
                                }
                            }
                            .scrollIndicators(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isSearchFocused = false
                            }
                            .onChange(of: selectedPrompt?.id) { _, newId in
                                if let id = newId {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
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

    @ViewBuilder
    private func promptGridCard(for prompt: Prompt) -> some View {
        PromptGridCard(
            prompt: prompt,
            isSelected: selectedPrompt?.id == prompt.id,
            isHovered: hoveredPrompt?.id == prompt.id,
            onTap: {
                selectedPrompt = prompt
                prewarmPreviewAssets(for: prompt)
                if showingPreview && preferences.soundEnabled {
                    SoundService.shared.playInteractionSound()
                }
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            },
            onDoubleTap: {
                selectedPrompt = prompt
                withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
            },
            onCopy: { usePrompt(prompt) },
            onHover: { isHovering in
                DispatchQueue.main.async { hoveredPrompt = isHovering ? prompt : nil }
                if isHovering { prewarmPreviewAssets(for: prompt) }
            }
        )
        .contextMenu { promptContextMenu(for: prompt) }
    }

    @ViewBuilder
    private func promptRow(for prompt: Prompt) -> some View {
        PromptCard(
            prompt: prompt,
            isSelected: selectedPrompt?.id == prompt.id,
            isHovered: hoveredPrompt?.id == prompt.id,
            onTap: {
                selectedPrompt = prompt
                prewarmPreviewAssets(for: prompt)
                if showingPreview && preferences.soundEnabled {
                    SoundService.shared.playInteractionSound()
                }
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            },
            onDoubleTap: {
                selectedPrompt = prompt
                withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
            },
            onCopy: { usePrompt(prompt) },
            onCopyPack: { copyPromptPack(prompt) },
            onHover: { isHovering in
                DispatchQueue.main.async { hoveredPrompt = isHovering ? prompt : nil }
                if isHovering { prewarmPreviewAssets(for: prompt) }
            }
        )
        .contextMenu { promptContextMenu(for: prompt) }
        .popover(
            isPresented: Binding(
                get: { showingPreview && selectedPrompt?.id == prompt.id },
                set: { if !$0 && selectedPrompt?.id == prompt.id { showingPreview = false } }
            ),
            arrowEdge: .top
        ) {
            PromptPreviewView(
                prompt: prompt,
                isFullScreenImageOpen: $isFullScreenImageOpen,
                onUse: { usePrompt(prompt) }
            )
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
            selectedPrompt = prompt
            if preferences.soundEnabled { SoundService.shared.playMagicSound() }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
        }
        Button(action: {
            selectedPrompt = prompt
            showingPreview = true
            if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
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
            selectedPrompt = prompt
            if preferences.soundEnabled { SoundService.shared.playInteractionSound() }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("Asignar Atajo", systemImage: "command.circle")
        }
        Button(action: {
            selectedPrompt = prompt
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
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if keyCode == 53 && modifiers.isEmpty {
            if fillingVariablesFor != nil {
                DispatchQueue.main.async { withAnimation { fillingVariablesFor = nil } }
                return nil
            }
            if showingPreview {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3)) { showingPreview = false }
                    if preferences.soundEnabled { SoundService.shared.playPreviewSound() }
                }
                return nil
            }
            let currentState = menuBarManager.activeViewState
            // En el editor (NewPromptView) dejamos que ese view maneje ESC primero
            // (overlays de variables/snippets, perder foco, etc.)
            if currentState == .newPrompt {
                return event
            }
            if currentState != .main {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        menuBarManager.activeViewState = .main
                        // No limpiar selectedPrompt al volver a .main:
                        // Si lo limpiamos, las flechas y Space dejan de funcionar
                        // porque no hay selección activa en la lista.
                        menuBarManager.folderToEdit = nil
                        menuBarManager.isModalActive = false
                    }
                }
                return nil
            }
        }
        guard case .main = menuBarManager.activeViewState, fillingVariablesFor == nil, !isFullScreenImageOpen, !menuBarManager.isModalActive else { return event }
        if keyCode == 36 {
            if selectedPrompt != nil {
                DispatchQueue.main.async { withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt } }
                return nil
            } else if let categoryName = promptService.selectedCategory, let folder = promptService.folders.first(where: { $0.name == categoryName }) {
                DispatchQueue.main.async {
                    menuBarManager.folderToEdit = folder
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { menuBarManager.activeViewState = .folderManager }
                }
                HapticService.shared.playLight()
                return nil
            }
        }
        if modifiers == .command && keyCode == 11 {
            DispatchQueue.main.async { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { preferences.showSidebar.toggle() } }
            return nil
        }
        if keyCode == 49 { // Space
            let isSearchEmpty = promptService.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
            let shouldTriggerPreview = isNavigatingWithKeys || isSearchEmpty || !isSearchFocused
            
            if shouldTriggerPreview {
                if showingPreview {
                    DispatchQueue.main.async {
                        showingPreview = false
                        if preferences.soundEnabled { SoundService.shared.playPreviewSound() }
                    }
                    return nil
                } else if selectedPrompt != nil {
                    DispatchQueue.main.async {
                        showingPreview = true
                        if preferences.soundEnabled { SoundService.shared.playPreviewSound() }
                    }
                    return nil
                }
            }
        }
        if keyCode == 14 { // 'e' key for edit
            if showingPreview, let _ = selectedPrompt {
                DispatchQueue.main.async {
                    showingPreview = false
                    if preferences.soundEnabled { SoundService.shared.playMagicSound() }
                    withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                }
                return nil
            }
        }
        if modifiers == .command && keyCode == 8 {
            if let prompt = selectedPrompt {
                DispatchQueue.main.async { usePrompt(prompt) }
                return nil
            }
        }
        if modifiers == .command && keyCode == 51 { // Cmd + Backspace
            if let prompt = selectedPrompt {
                DispatchQueue.main.async { deletePrompt(prompt) }
                return nil
            }
        }
        if keyCode == 126 { // Up
            guard !promptService.filteredPrompts.isEmpty else { return event }
            isNavigatingWithKeys = true
            DispatchQueue.main.async {
                if let currentPrompt = selectedPrompt, let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                    if currentIndex > 0 {
                        selectedPrompt = promptService.filteredPrompts[currentIndex - 1]
                        if showingPreview && preferences.soundEnabled { SoundService.shared.playInteractionSound() }
                        HapticService.shared.playLight()
                    }
                } else {
                    selectedPrompt = promptService.filteredPrompts.first
                    HapticService.shared.playLight()
                }
            }
            return nil
        }
        if keyCode == 125 { // Down
            guard !promptService.filteredPrompts.isEmpty else { return event }
            isNavigatingWithKeys = true
            DispatchQueue.main.async {
                if let currentPrompt = selectedPrompt, let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                    if currentIndex < promptService.filteredPrompts.count - 1 {
                        selectedPrompt = promptService.filteredPrompts[currentIndex + 1]
                        if showingPreview && preferences.soundEnabled { SoundService.shared.playInteractionSound() }
                        HapticService.shared.playLight()
                    }
                } else {
                    selectedPrompt = promptService.filteredPrompts.first
                    HapticService.shared.playLight()
                }
            }
            return nil
        }
        return event
    }
    
    private func usePrompt(_ prompt: Prompt) {
        if prompt.hasTemplateVariables() || prompt.hasChains() {
            if prompt.isSmartOnly() && !prompt.hasChains() {
                let resolvedContent = PlaceholderResolver.shared.resolveAll(in: prompt.content)
                self.promptService.usePrompt(prompt, contentOverride: resolvedContent)
            } else {
                if self.showingPreview { self.showingPreview = false }
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
        if self.showingPreview { self.showingPreview = false }
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
        if showingPreview { showingPreview = false }
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
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        _ = self.promptService.updatePrompt(updatedPrompt)
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
        showingPreview = false
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
                let paths: [String] = !prompt.showcaseImagePaths.isEmpty
                    ? prompt.showcaseImagePaths
                    : await promptService.fetchShowcaseImagePaths(byId: prompt.id)

                if let first = paths.first {
                    let url = ImageStore.shared.url(forRelativePath: first)
                    let cacheKey = "\(prompt.id.uuidString):preview:0:1600:\(first)"
                    await ImageDecodeThrottler.prewarm(url: url, cacheKey: cacheKey, maxPixelSize: 1600)
                }
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
}

// MARK: - Guía Visual de Redimensionado HUD
struct ResizingGuideView: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.1).edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 70, height: 70)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 28, weight: .bold)).foregroundColor(.blue)
                }
                VStack(spacing: 6) {
                    Text(NSLocalizedString("target_size", comment: "")).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).tracking(1.5).textCase(.uppercase)
                    HStack(spacing: 25) {
                        VStack {
                            Text("\(Int(preferences.previewWidth))").font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("width", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Divider().frame(height: 35)
                        VStack {
                            Text("\(Int(preferences.previewHeight))").font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("height", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                Text(NSLocalizedString("release_to_apply", comment: "")).font(.system(size: 10, weight: .medium)).foregroundColor(.blue.opacity(0.7)).padding(.horizontal, 12).padding(.vertical, 4).background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            .padding(32).background(RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.25), radius: 25, y: 12))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.primary.opacity(0.1), lineWidth: 1))
        }
    }
}

struct AccessibilityBanner: View {
    @EnvironmentObject var preferences: PreferencesManager
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundColor(.orange).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("accessibility_permissions", comment: "")).font(.system(size: 12, weight: .bold))
                Text(NSLocalizedString("accessibility_required_for_paste", comment: "")).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(NSLocalizedString("configure", comment: "")) { ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true, ignoreSuppression: true) }.buttonStyle(.bordered).controlSize(.small)
                Button(action: { withAnimation { preferences.suppressAccessibilityWarning = true } }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).padding(6).background(Color.primary.opacity(0.05)).clipShape(Circle())
                }.buttonStyle(.plain).help(NSLocalizedString("do_not_show_again", comment: ""))
            }
        }.padding(.horizontal, 16).padding(.vertical, 10).background(Color.orange.opacity(0.08)).overlay(Rectangle().frame(height: 1).foregroundColor(.orange.opacity(0.15)), alignment: .bottom)
    }
}

struct ClipboardSuggestionBanner: View {
    let content: String
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @State private var progress: CGFloat = 1.0
    @State private var isHovered: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .blur(radius: isHovered ? 8 : 4)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                    .shadow(color: preferences.isHaloEffectEnabled ? .blue.opacity(0.5) : .clear, radius: isHovered ? 8 : 5)
            }
            .scaleEffect(isHovered ? 1.0 : 1.0)
            VStack(alignment: .leading, spacing: 2) {
                Text("clipboard_banner_title".localized(for: preferences.language)).font(.system(size: 12, weight: .bold)).foregroundColor(.primary.opacity(0.9))
                Text(content).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
            Button(action: {
                let newPrompt = Prompt(title: "", content: content, folder: nil, tags: [])
                DraftService.shared.saveDraft(prompt: newPrompt, isEditing: false)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .newPrompt
                    menuBarManager.isModalActive = true
                    menuBarManager.suggestedClipboardContent = nil
                }
                HapticService.shared.playLight()
            }) {
                Text("clipboard_banner_action".localized(for: preferences.language))
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            if preferences.isHaloEffectEnabled {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: .blue.opacity(0.4), radius: isHovered ? 10 : 6, y: isHovered ? 4 : 2)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            }
                        }
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            Button(action: { withAnimation(.easeOut(duration: 0.25)) { menuBarManager.suggestedClipboardContent = nil } }) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .black)).foregroundColor(.secondary.opacity(0.5)).frame(width: 26, height: 26).background(Circle().fill(Color.primary.opacity(0.04)))
            }.buttonStyle(.plain)
        }.padding(12)
        .frame(maxWidth: preferences.windowWidth * 0.65)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                if preferences.isHaloEffectEnabled {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.03), .clear, .blue.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.15), radius: isHovered ? 25 : 20, y: isHovered ? 12 : 10)
        )
        .overlay(
            ZStack(alignment: .bottom) {
                // Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .primary.opacity(isHovered ? 0.25 : 0.12),
                                .primary.opacity(0.05),
                                .primary.opacity(isHovered ? 0.2 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Progress Bar (Timer)
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .blue.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 2)
                        .cornerRadius(1)
                }
                .frame(height: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
                .opacity(0.8)
            }
        )
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .offset(y: isHovered ? -1 : 0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.3)) {
                progress = 0.0
            }
        }
        .padding(.bottom, 8)
    }
}
