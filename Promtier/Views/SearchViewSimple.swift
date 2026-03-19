import SwiftUI
import AppKit
import UniformTypeIdentifiers

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @FocusState private var isSearchFocused: Bool
    @State private var localEventMonitor: Any?
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
    @State private var fillingVariablesFor: Prompt?
    @State private var showParticles: Bool = false
    @State private var isDraggingFile: Bool = false
    @State private var importMessage: String? = nil
    @State private var showingImportAlert: Bool = false
    @State private var importData: Data? = nil
    @State private var importURL: URL? = nil
    /// Bloquea atajos de teclado cuando hay una hoja/modal secundaria abierta
    @State private var isFullScreenImageOpen: Bool = false
    // Prewarm de thumbnails para evitar beachball al abrir preview tras arrancar.
    @State private var prewarmTask: Task<Void, Never>? = nil
    @State private var lastPrewarmedPromptId: UUID? = nil
    
    // Ghost Tips logic
    @State private var currentGhostTip: GhostTip? = nil
    @State private var nextTipIndex: Int = 0
    private var ghostTips: [GhostTip] {
        [
            // Navegación y Lista
            GhostTip(title: "gt_move_selection".localized(for: preferences.language), icon: "arrow.up", shortcut: "gt_move_shortcut".localized(for: preferences.language)),
            GhostTip(title: "preview".localized(for: preferences.language), icon: "eye", shortcut: "gt_spacebar".localized(for: preferences.language)),
            GhostTip(title: "copy".localized(for: preferences.language), icon: "doc.on.doc", shortcut: "Cmd + C"),
            GhostTip(title: "edit".localized(for: preferences.language), icon: "pencil", shortcut: "gt_edit_shortcut".localized(for: preferences.language)),
            GhostTip(title: "toggle_sidebar".localized(for: preferences.language), icon: "sidebar.left", shortcut: "Cmd + B"),
            GhostTip(title: "new_prompt".localized(for: preferences.language), icon: "plus", shortcut: "Cmd + N"),
            GhostTip(title: "settings".localized(for: preferences.language), icon: "gearshape", shortcut: "Cmd + ,"),
            
            // Editor
            GhostTip(title: "save_prompt".localized(for: preferences.language), icon: "square.and.arrow.down", shortcut: "Cmd + S"),
            GhostTip(title: "gt_snippets_shortcut".localized(for: preferences.language), icon: "text.quote", shortcut: "/"),
            GhostTip(title: "insert_variable".localized(for: preferences.language), icon: "curlybraces", shortcut: "gt_variables_shortcut".localized(for: preferences.language)),
            GhostTip(title: "focus_negative".localized(for: preferences.language), icon: "minus.circle", shortcut: "⌥ N"),
            GhostTip(title: "focus_alternative".localized(for: preferences.language), icon: "plus.circle", shortcut: "⌥ A"),
            
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
            case .trash:
                TrashView()
                    .environmentObject(promptService)
                    .environmentObject(preferences)
                    .environmentObject(menuBarManager)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
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
            if let tip = currentGhostTip, preferences.ghostTipsEnabled && menuBarManager.activeViewState == .main {
                VStack {
                    Spacer()
                    GhostTipView(tip: tip) {
                        currentGhostTip = nil
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
                .padding(.bottom, batchService.isSelectionModeActive ? 90 : 24) // Evitar solapamiento con la barra de lote
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
        .onChange(of: preferences.windowWidth) { oldWidth, newWidth in
            let threshold: CGFloat = 565
            
            // Solo auto-ocultar/mostrar en la vista principal
            guard menuBarManager.activeViewState == .main else { return }
            
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
            
            // Programar primer Ghost Tip si están activados
            if preferences.ghostTipsEnabled {
                scheduleNextGhostTip(initialDelay: 3.0)
            }
            
            if localEventMonitor == nil {
                localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    return handleLocalKeyEvent(event)
                }
            }
        }
        .onDisappear {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
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
        HStack(spacing: 0) {
            // Sidebar de categorías
            if preferences.showSidebar {
                CategorySidebar()
                    .environmentObject(promptService)
                    .transition(.move(edge: .leading).combined(with: .opacity))
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
                        // Botón Colapsar Sidebar
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                preferences.showSidebar.toggle()
                            }
                        }) {
                            Image(systemName: preferences.showSidebar ? "sidebar.left" : "sidebar.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(preferences.showSidebar ? .blue : .secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(preferences.showSidebar ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preferences.showSidebar ? "hide_sidebar_help".localized(for: preferences.language) : "show_sidebar_help".localized(for: preferences.language))
                        
                        // Buscador Estilizado
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                            
                            TextField("search_placeholder".localized(for: preferences.language), text: $promptService.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15 * preferences.fontSize.scale))
                                .focused($isSearchFocused)
                                .onChange(of: promptService.searchQuery) { _, newValue in
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
                                            .fill(Color.blue)
                                            .shadow(color: Color.blue.opacity(0.3), radius: 4, y: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("new_prompt".localized(for: preferences.language) + " (N)")
                            
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
                                            .fill(batchService.isSelectionModeActive ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(batchService.isSelectionModeActive ? Color.blue.opacity(0.2) : Color.primary.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
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
                                            .fill(Color.primary.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("settings".localized(for: preferences.language) + " (Cmd+,)")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider().padding(.horizontal, 24)
                
                // Contenido principal
                if promptService.filteredPrompts.isEmpty {
                    VStack(spacing: 32) {
                        Spacer()
                        
                        Image(systemName: "text.bubble")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
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
                    .padding(.horizontal, 24)
                } else {
                    // Lista moderna de prompts
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(promptService.filteredPrompts, id: \.id) { prompt in
                                    promptRow(for: prompt)
                                        .id(prompt.id)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .onChange(of: selectedPrompt?.id) { _, newId in
                            if let id = newId {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                                
                                // Sonido eliminado de aquí por ser demasiado lento/insuficiente
                            }
                        }
                    }
                    .onChange(of: showingPreview) { _, isShowing in
                        if isShowing && preferences.soundEnabled {
                            SoundService.shared.playInteractionSound()
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
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
    private func promptRow(for prompt: Prompt) -> some View {
        PromptCard(
            prompt: prompt,
            isSelected: selectedPrompt?.id == prompt.id,
            isHovered: hoveredPrompt?.id == prompt.id,
            onTap: {
                selectedPrompt = prompt
                prewarmPreviewImages(for: prompt)

                // Sonido si la vista previa está abierta
                if showingPreview && preferences.soundEnabled {
                    SoundService.shared.playInteractionSound()
                }

                // Forzar foco a la ventana principal
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            },
            onDoubleTap: {
                selectedPrompt = prompt
                withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
            },
            onCopy: {
                usePrompt(prompt)
            },
            onCopyPack: {
                copyPromptPack(prompt)
            },
            onHover: { isHovering in
                DispatchQueue.main.async {
                    hoveredPrompt = isHovering ? prompt : nil
                }
                if isHovering {
                    prewarmPreviewImages(for: prompt)
                }
            }
        )
        .contextMenu {
            promptContextMenu(for: prompt)
        }
        .popover(
            isPresented: Binding(
                get: { showingPreview && selectedPrompt?.id == prompt.id },
                set: { if !$0 && selectedPrompt?.id == prompt.id { showingPreview = false } }
            ),
            arrowEdge: .top
        ) {
            PromptPreviewView(
                prompt: prompt,
                isFullScreenImageOpen: $isFullScreenImageOpen
            )
        }
    }

    @ViewBuilder
    private func promptContextMenu(for prompt: Prompt) -> some View {
        Button(action: { usePrompt(prompt) }) {
            Label("copy".localized(for: preferences.language), systemImage: "doc.on.doc")
        }

        Button(action: { copyPromptPack(prompt) }) {
            Label("copy_pack".localized(for: preferences.language), systemImage: "doc.on.doc")
        }

        Button(action: {
            selectedPrompt = prompt
            if preferences.soundEnabled {
                SoundService.shared.playMagicSound()
            }
            withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
        }) {
            Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
        }

        Button(action: {
            selectedPrompt = prompt
            showingPreview = true
            if preferences.soundEnabled {
                SoundService.shared.playInteractionSound()
            }
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

        Button(action: {
            if preferences.soundEnabled {
                SoundService.shared.playInteractionSound()
            }
            exportPromptsToFile(prompt)
        }) {
            Label("export_plain_text".localized(for: preferences.language), systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive, action: { deletePrompt(prompt) }) {
            Label("delete".localized(for: preferences.language), systemImage: "trash.fill")
        }
    }
    
    /// Maneja eventos de teclado locales para Cmd+C, Enter y navegación
    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode
        
        // ESC (KeyCode 53): cerrar solo el overlay de Variables si está abierto
        if keyCode == 53 {
            if fillingVariablesFor != nil {
                DispatchQueue.main.async { withAnimation { fillingVariablesFor = nil } }
                return nil  // consumir el evento — no cerrar la app
            }
        }
        
        // GUARDIA PRINCIPAL: solo actuar en vista principal, sin overlays ni modales abiertos
        guard case .main = menuBarManager.activeViewState,
              fillingVariablesFor == nil,
              !isFullScreenImageOpen,
              !menuBarManager.isModalActive else { return event }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Enter (KeyCode 36) -> Editar
        if keyCode == 36 {
            if selectedPrompt != nil {
                DispatchQueue.main.async {
                    withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt }
                }
                return nil
            }
        }
        
        // Cmd + B (KeyCode 11) -> Alternar Sidebar
        if modifiers == .command && keyCode == 11 {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    preferences.showSidebar.toggle()
                }
            }
            return nil
        }
        
        // Espacio (KeyCode 49) -> Vista Previa (Quick Look)
        if keyCode == 49 {
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
        
        // Cmd + C (KeyCode 8) -> Copiar
        if modifiers == .command && keyCode == 8 {
            if let prompt = selectedPrompt {
                DispatchQueue.main.async {
                    usePrompt(prompt)
                }
                return nil
            }
        }
        
        // Flecha Arriba (KeyCode 126)
        if keyCode == 126 {
            guard !promptService.filteredPrompts.isEmpty else { return event }
            DispatchQueue.main.async {
                if let currentPrompt = selectedPrompt,
                   let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                    if currentIndex > 0 {
                        selectedPrompt = promptService.filteredPrompts[currentIndex - 1]
                        
                        // Sonido forzado para navegación por teclado
                        if showingPreview && preferences.soundEnabled {
                            SoundService.shared.playInteractionSound()
                        }
                        HapticService.shared.playLight()
                    }
                } else {
                    selectedPrompt = promptService.filteredPrompts.first
                    HapticService.shared.playLight()
                }
            }
            return nil
        }
        
        // Flecha Abajo (KeyCode 125)
        if keyCode == 125 {
            guard !promptService.filteredPrompts.isEmpty else { return event }
            DispatchQueue.main.async {
                if let currentPrompt = selectedPrompt,
                   let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                    if currentIndex < promptService.filteredPrompts.count - 1 {
                        selectedPrompt = promptService.filteredPrompts[currentIndex + 1]
                        
                        // Sonido forzado para navegación por teclado
                        if showingPreview && preferences.soundEnabled {
                            SoundService.shared.playInteractionSound()
                        }
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
    
    // MARK: - Métodos
    
    /// Usa un prompt (copia al clipboard) - Versión optimizada
    private func usePrompt(_ prompt: Prompt) {
        // Si tiene variables, mostrar el formulario primero
        if prompt.hasTemplateVariables() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                fillingVariablesFor = prompt
            }
            return
        }
        
        self.promptService.usePrompt(prompt)
        
        // Lógica de Post-Copia: Sonido, Háptica, Cerrar y Preview
        if self.preferences.soundEnabled {
            SoundService.shared.playCopySound()
        }
        HapticService.shared.playAlignment()
        
        // Efectos Visuales
        if self.preferences.isPremiumActive && self.preferences.visualEffectsEnabled {
            self.showParticles = false // Reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.showParticles = true
            }
        }
        
        // Cerrar preview si está abierto
        if self.showingPreview {
            self.showingPreview = false
        }
        
        // CERRAR VENTANA: Si la preferencia está activa
        if self.preferences.closeOnCopy {
            if self.preferences.isPremiumActive && self.preferences.visualEffectsEnabled {
                // Dar tiempo para ver las partículas
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.menuBarManager.closePopover()
                }
            } else {
                self.menuBarManager.closePopover()
            }
        }
    }

    /// Copia un "pack" del prompt: Main + Negative + Alternatives (si existen)
    private func copyPromptPack(_ prompt: Prompt) {
        var packPrompt = prompt

        var parts: [String] = [prompt.content]

        if let negative = prompt.negativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !negative.isEmpty {
            let title = "negative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(negative)")
        }

        // Incluir alternativas de la lista nueva
        for (index, alt) in prompt.alternatives.enumerated() {
            let trimmed = alt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let title = "\("alternative".localized(for: preferences.language)) #\(index + 1)"
                parts.append("\n\n\(title):\n\(trimmed)")
            }
        }

        // Fallback para datos antiguos si la lista nueva está vacía
        if prompt.alternatives.isEmpty, 
           let alternative = prompt.alternativePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !alternative.isEmpty {
            let title = "alternative_prompt".localized(for: preferences.language)
            parts.append("\n\n\(title):\n\(alternative)")
        }

        packPrompt.content = parts.joined()
        usePrompt(packPrompt)
    }
    
    /// Cambia el estado de favorito de un prompt - Versión optimizada
    private func toggleFavorite(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        
        _ = self.promptService.updatePrompt(updatedPrompt)
        
        // Sonido y Háptica
        if self.preferences.soundEnabled {
            SoundService.shared.playFavoriteSound()
        }
        HapticService.shared.playImpact()
    }
    
    /// Elimina un prompt - Versión optimizada
    private func deletePrompt(_ prompt: Prompt) {
        if batchService.isSelectionModeActive,
           batchService.selectedPromptIds.contains(prompt.id),
           batchService.selectedPromptIds.count > 1 {
            _ = promptService.deletePrompts(withIds: Array(batchService.selectedPromptIds))
            withAnimation(.spring()) {
                batchService.clearSelection()
            }
        } else {
            _ = self.promptService.deletePrompt(prompt)
            if batchService.isSelectionModeActive {
                batchService.selectedPromptIds.remove(prompt.id)
            }
        }
        
        if self.preferences.soundEnabled {
            SoundService.shared.playDeleteSound()
        }
    }
    
    /// Exporta un prompt específico a un archivo de texto
    private func exportPromptsToFile(_ prompt: Prompt) {
        let exportContent = "# \(prompt.title)\n\n\(prompt.content)"
        
        let fileName = "\(prompt.title.replacingOccurrences(of: " ", with: "_")).md"
        
        // Crear el diálogo de guardar nativo de macOS
        let savePanel = NSSavePanel()
        if let mdType = UTType(filenameExtension: "md") {
            savePanel.allowedContentTypes = [mdType, .plainText]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }
        savePanel.nameFieldStringValue = fileName
        savePanel.title = "export_prompts_title".localized(for: preferences.language)
        savePanel.message = "export_prompts_message".localized(for: preferences.language)
        
        // Hacer la app activa para evitar errores de ViewBridge y paneles en background
        NSApp.activate(ignoringOtherApps: true)
        
        // Cerrar el popover inmediatamente para que solo quede el diálogo del Finder
        self.menuBarManager.closePopover()
        
        // Mostrar el diálogo y esperar respuesta del usuario
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try exportContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
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
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: isDraggingFile ? 3 : 0)
                .padding(4)
                .allowsHitTesting(false)
            
            if let msg = importMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private func prewarmPreviewImages(for prompt: Prompt) {
        guard prompt.showcaseImageCount > 0 else { return }
        if lastPrewarmedPromptId == prompt.id { return }
        lastPrewarmedPromptId = prompt.id

        prewarmTask?.cancel()
        prewarmTask = Task(priority: .utility) {
            let paths: [String]
            if !prompt.showcaseImagePaths.isEmpty {
                paths = prompt.showcaseImagePaths
            } else {
                paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            }
            guard let first = paths.first else { return }
            let url = ImageStore.shared.url(forRelativePath: first)
            let cacheKey = "\(prompt.id.uuidString):preview:0:900:\(first)"
            await ImageDecodeThrottler.prewarm(url: url, cacheKey: cacheKey, maxPixelSize: 900)
        }
    }
    
    /// Programa la aparición de un Ghost Tip en serie
    private func scheduleNextGhostTip(initialDelay: Double? = nil) {
        guard preferences.ghostTipsEnabled else { return }
        
        // Usar delay inicial (ej: 3s) si se solicita, si no, uno aleatorio normal
        let delay = initialDelay ?? Double.random(in: 25...45)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Solo mostrar si seguimos en la pantalla principal y están activados
            if self.menuBarManager.activeViewState == .main && self.preferences.ghostTipsEnabled && self.currentGhostTip == nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    // Mostrar siguiente en la serie (bucle)
                    self.currentGhostTip = self.ghostTips[self.nextTipIndex % self.ghostTips.count]
                    self.nextTipIndex += 1
                }
                
                // ⏱️ Auto-ocultar después de 6.5 segundos (ajustado por petición)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                    if self.currentGhostTip != nil {
                        withAnimation(.easeOut(duration: 0.4)) {
                            self.currentGhostTip = nil
                        }
                    }
                }
            }
            
            // Programar el siguiente tip en serie (sin delay inicial forzado)
            self.scheduleNextGhostTip()
        }
    }
}

// MARK: - Guía Visual de Redimensionado HUD
struct ResizingGuideView: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ZStack {
            // Fondo traslúcido sutil para enfocar el HUD
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
            
            // HUD Central Flotante (Referencia visual de la animación)
            VStack(spacing: 20) {
                // Icono dinámico
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 6) {
                    Text(NSLocalizedString("target_size", comment: ""))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 25) {
                        VStack {
                            Text("\(Int(preferences.previewWidth))")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("width", comment: ""))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 35)
                        
                        VStack {
                            Text("\(Int(preferences.previewHeight))")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("height", comment: ""))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Indicador de "Soltar para aplicar"
                Text(NSLocalizedString("release_to_apply", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 25, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Componentes de Soporte

struct AccessibilityBanner: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("accessibility_permissions", comment: ""))
                    .font(.system(size: 12, weight: .bold))
                Text(NSLocalizedString("accessibility_required_for_paste", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(NSLocalizedString("configure", comment: "")) {
                    ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true, ignoreSuppression: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: {
                    withAnimation {
                        preferences.suppressAccessibilityWarning = true
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("do_not_show_again", comment: ""))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.orange.opacity(0.15)),
            alignment: .bottom
        )
    }
}
