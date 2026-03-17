import SwiftUI
import AppKit
import UniformTypeIdentifiers

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @FocusState private var isSearchFocused: Bool
    @State private var localEventMonitor: Any?
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
    @State private var fillingVariablesFor: Prompt?
    
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
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .preferences:
                PreferencesView(onClose: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        menuBarManager.activeViewState = .main
                    }
                })
                .environmentObject(preferences)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .folderManager:
                FolderManagerView(folderToEdit: menuBarManager.folderToEdit, onClose: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        menuBarManager.folderToEdit = nil // Limpiar al cerrar
                        menuBarManager.activeViewState = .main
                    }
                })
                .environmentObject(promptService)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
            
            // Overlay de Variables Dinámicas
            if let prompt = fillingVariablesFor {
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
                    }, onCancel: {
                        withAnimation { fillingVariablesFor = nil }
                    })
                    .transition(.scale.combined(with: .opacity))
                    .environmentObject(preferences)
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
        }
        .frame(width: preferences.windowWidth, height: preferences.windowHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(preferences.appearance == .dark ? .dark : (preferences.appearance == .light ? .light : nil))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
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
                        .help(preferences.showSidebar ? "Ocultar Sidebar" : "Mostrar Sidebar")
                        
                        // Buscador Estilizado
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                            
                            TextField("Buscar tus prompts...", text: $promptService.searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15 * preferences.fontSize.scale))
                                .focused($isSearchFocused)
                            
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
                            .help("Nuevo Prompt (N)")
                            
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
                            .help("Configuración (Cmd+,)")
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
                            Text(promptService.searchQuery.isEmpty ? "No hay prompts aún" : "No se encontraron resultados")
                                .font(.system(size: 20 * preferences.fontSize.scale, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(promptService.searchQuery.isEmpty ? "Crea tu primer prompt para comenzar" : "Intenta con otros términos de búsqueda")
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .foregroundColor(.secondary)
                        }
                        
                        if promptService.searchQuery.isEmpty {
                            Button("Crear Primer Prompt") {
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
                                    PromptCard(
                                        prompt: prompt,
                                        isSelected: selectedPrompt?.id == prompt.id,
                                        isHovered: hoveredPrompt?.id == prompt.id,
                                        onTap: {
                                            // Optimización: Actualizar estado de forma síncrona
                                            selectedPrompt = prompt
                                        
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
                                        onHover: { isHovering in
                                            // Optimización: Reducir actualizaciones de hover
                                            DispatchQueue.main.async {
                                                hoveredPrompt = isHovering ? prompt : nil
                                            }
                                        }
                                    )
                                    .id(prompt.id)
                                    .popover(isPresented: Binding(
                                        get: { showingPreview && selectedPrompt?.id == prompt.id },
                                        set: { if !$0 && selectedPrompt?.id == prompt.id { showingPreview = false } }
                                    ), arrowEdge: .top) {
                                        PromptPreviewView(prompt: prompt)
                                    }
                                    .contextMenu {
                                    Button(action: { usePrompt(prompt) }) {
                                        Label("Copiar", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: { 
                                        selectedPrompt = prompt
                                        if preferences.soundEnabled {
                                            SoundService.shared.playMagicSound()
                                        }
                                        withAnimation(.spring()) { menuBarManager.activeViewState = .newPrompt } 
                                    }) {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    
                                    Button(action: { toggleFavorite(prompt) }) {
                                        Label(prompt.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos", 
                                              systemImage: prompt.isFavorite ? "star.slash" : "star.fill")
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: { 
                                        if preferences.soundEnabled {
                                            SoundService.shared.playInteractionSound()
                                        }
                                        exportPromptsToFile(prompt) 
                                    }) {
                                        Label("Exportar a texto plano", systemImage: "square.and.arrow.up")
                                    }
                                    
                                    Button(role: .destructive, action: { deletePrompt(prompt) }) {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .onChange(of: selectedPrompt?.id) { newId in
                            if let id = newId {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                                
                                // Sonido eliminado de aquí por ser demasiado lento/insuficiente
                            }
                        }
                    }
                    .onChange(of: showingPreview) { isShowing in
                        if isShowing && preferences.soundEnabled {
                            SoundService.shared.playInteractionSound()
                        }
                    }
                }
            }
        }
    }
    
    /// Maneja eventos de teclado locales para Cmd+C, Enter y navegación
    private func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Solo manejar si estamos en la vista principal
        guard case .main = menuBarManager.activeViewState, fillingVariablesFor == nil else { return event }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        
        // Enter (KeyCode 36) -> Editar
        if keyCode == 36 {
            if let prompt = selectedPrompt {
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
                DispatchQueue.main.async { showingPreview = false }
                return nil
            } else if selectedPrompt != nil {
                DispatchQueue.main.async { 
                    showingPreview = true 
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
                    }
                } else {
                    selectedPrompt = promptService.filteredPrompts.first
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
                    }
                } else {
                    selectedPrompt = promptService.filteredPrompts.first
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
        
        if self.preferences.soundEnabled {
            SoundService.shared.playCopySound()
        }
        
        // Cerrar preview si está abierto
        if self.showingPreview {
            self.showingPreview = false
        }
    }
    
    /// Cambia el estado de favorito de un prompt - Versión optimizada
    private func toggleFavorite(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        
        _ = self.promptService.updatePrompt(updatedPrompt)
        
        // Sonido
        if self.preferences.soundEnabled {
            SoundService.shared.playFavoriteSound()
        }
    }
    
    /// Elimina un prompt - Versión optimizada
    private func deletePrompt(_ prompt: Prompt) {
        _ = self.promptService.deletePrompt(prompt)
        
        if self.preferences.soundEnabled {
            SoundService.shared.playDeleteSound()
        }
    }
    
    /// Exporta un prompt específico a un archivo de texto
    private func exportPromptsToFile(_ prompt: Prompt) {
        let exportContent = "Título: \(prompt.title)\n\n\(prompt.content)"
        
        let fileName = "\(prompt.title.replacingOccurrences(of: " ", with: "_")).txt"
        
        // Crear el diálogo de guardar nativo de macOS
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = fileName
        savePanel.title = "Exportar Prompts"
        savePanel.message = "Elige dónde guardar el archivo de prompts exportados"
        
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
                    alert.messageText = "Error al exportar"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
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
                    Text("Tamaño Objetivo")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    
                    HStack(spacing: 25) {
                        VStack {
                            Text("\(Int(preferences.previewWidth))")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text("ancho")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().frame(height: 35)
                        
                        VStack {
                            Text("\(Int(preferences.previewHeight))")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text("alto")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Indicador de "Soltar para aplicar"
                Text("Suelta para aplicar cambios")
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
