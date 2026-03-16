//
//  SearchViewSimple.swift
//  Promtier
//
//  VISTA PRINCIPAL SIMPLIFICADA: Interfaz básica de búsqueda
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    enum ViewState {
        case main
        case newPrompt
        case editPrompt(Prompt)
        case preferences
    }
    
    @State private var viewState: ViewState = .main
    @FocusState private var isSearchFocused: Bool
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
    @State private var fillingVariablesFor: Prompt?
    
    var body: some View {
        ZStack {
            switch viewState {
            case .main:
                mainView
            case .newPrompt:
                NewPromptView(onClose: { viewState = .main })
                    .environmentObject(promptService)
                    .environmentObject(preferences)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .editPrompt(let prompt):
                NewPromptView(prompt: prompt, onClose: { viewState = .main })
                    .environmentObject(promptService)
                    .environmentObject(preferences)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .preferences:
                PreferencesView(onClose: { viewState = .main })
                    .environmentObject(preferences)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)))
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
                    promptService.recordPromptUse(prompt) // Solo registrar uso, NO copiar base
                    withAnimation { fillingVariablesFor = nil }
                        
                        // Sonido y feedback
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
        }
        .frame(width: 650, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(preferences.appearance == .dark ? .dark : (preferences.appearance == .light ? .light : nil))
        .onAppear {
            // Asegurar foco en la ventana
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
        }
        .onChange(of: menuBarManager.activeViewState) { newState in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                switch newState {
                case .main:
                    viewState = .main
                    isSearchFocused = true
                case .newPrompt:
                    viewState = .newPrompt
                case .preferences:
                    viewState = .preferences
                }
            }
        }
        .popover(isPresented: $showingPreview) {
            if let prompt = selectedPrompt {
                PromptPreviewView(prompt: prompt)
                    .onKeyPress(.space) {
                        showingPreview = false
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        showingPreview = false
                        return .handled
                    }
            }
        }
    }
    
    private var mainView: some View {
        HStack(spacing: 0) {
            // Sidebar de categorías
            CategorySidebar()
                .environmentObject(promptService)
            
            // Contenido principal
            VStack(spacing: 0) {
                // Header Premium con búsqueda
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
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
                            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewState = .newPrompt } }) {
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
                            
                            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewState = .preferences } }) {
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
                                withAnimation(.spring()) { viewState = .newPrompt }
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
                                        // Forzar foco a la ventana principal
                                        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                                    },
                                    onDoubleTap: {
                                        withAnimation(.spring()) { viewState = .editPrompt(prompt) }
                                    },
                                    onHover: { isHovering in
                                        // Optimización: Reducir actualizaciones de hover
                                        DispatchQueue.main.async {
                                            hoveredPrompt = isHovering ? prompt : nil
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button("Copiar") {
                                        usePrompt(prompt)
                                    }
                                    
                                    Button("Editar") { 
                                        withAnimation(.spring()) { viewState = .editPrompt(prompt) }
                                    }
                                    
                                    Divider()
                                    
                                    Button("Exportar a texto plano") {
                                        exportPromptsToFile()
                                    }
                                    
                                    Button("Eliminar") { deletePrompt(prompt) }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .onKeyPress(.space) {
            // Optimización: Manejo más eficiente del espacio
            if showingPreview {
                showingPreview = false
                return .handled
            } else if selectedPrompt != nil {
                // Solo mostrar preview si hay un prompt seleccionado
                showingPreview = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            // Optimización: Navegación más fluida
            guard !promptService.filteredPrompts.isEmpty else { return .ignored }
            
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                if currentIndex > 0 {
                    selectedPrompt = promptService.filteredPrompts[currentIndex - 1]
                    return .handled
                }
            } else {
                // Seleccionar primer elemento si no hay selección
                selectedPrompt = promptService.filteredPrompts.first
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            // Optimización: Navegación más fluida
            guard !promptService.filteredPrompts.isEmpty else { return .ignored }
            
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }) {
                if currentIndex < promptService.filteredPrompts.count - 1 {
                    selectedPrompt = promptService.filteredPrompts[currentIndex + 1]
                    return .handled
                }
            } else {
                // Seleccionar primer elemento si no hay selección
                selectedPrompt = promptService.filteredPrompts.first
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            // Optimización: Manejo más eficiente del Enter
            if let prompt = selectedPrompt {
                withAnimation(.spring()) { viewState = .editPrompt(prompt) }
                // Cerrar preview si está abierto
                if showingPreview {
                    showingPreview = false
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "c"), phases: .down) { press in
            // Cmd + C para copiar el prompt seleccionado
            if press.modifiers.contains(.command), let prompt = selectedPrompt {
                usePrompt(prompt)
                return .handled
            }
            return .ignored
        }
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
            SoundService.shared.playInteractionSound()
        }
    }
    
    /// Elimina un prompt - Versión optimizada
    private func deletePrompt(_ prompt: Prompt) {
        _ = self.promptService.deletePrompt(prompt)
    }
    
    /// Exporta todos los prompts a un archivo de texto
    private func exportPromptsToFile() {
        let exportContent = promptService.exportAllPrompts()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "prompts_export_\(timestamp).txt"
        
        // Crear el diálogo de guardar nativo de macOS
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = fileName
        savePanel.title = "Exportar Prompts"
        savePanel.message = "Elige dónde guardar el archivo de prompts exportados"
        
        // Hacer la app activa para evitar errores de ViewBridge y paneles en background
        NSApp.activate(ignoringOtherApps: true)
        
        // Mostrar el diálogo y esperar respuesta del usuario
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try exportContent.write(to: url, atomically: true, encoding: .utf8)
                    
                    // Mostrar notificación de éxito
                    let alert = NSAlert()
                    alert.messageText = "Exportación completada"
                    alert.informativeText = "Los prompts han sido exportados a:\n\(url.lastPathComponent)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    
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
