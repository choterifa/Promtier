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
    
    enum ViewState {
        case main
        case newPrompt
        case editPrompt(Prompt)
        case detail(Prompt)
        case preferences
    }
    
    @State private var viewState: ViewState = .main
    @State private var selectedPrompt: Prompt?
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
    
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
            case .detail(let prompt):
                PromptDetailView(prompt: prompt, onClose: { viewState = .main }, onEdit: { p in viewState = .editPrompt(p) })
                    .environmentObject(promptService)
                    .environmentObject(preferences)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .preferences:
                PreferencesView(onClose: { viewState = .main })
                    .environmentObject(preferences)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)))
            }
        }
        .frame(width: 650, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Asegurar foco en la ventana
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
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
                // Header estandarizado con búsqueda
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Text("Promtier")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Cerrar") {
                            NSApplication.shared.keyWindow?.close()
                        }
                        .keyboardShortcut(.escape)
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        TextField("Buscar prompts...", text: $promptService.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        
                        Button(action: { withAnimation(.spring()) { viewState = .newPrompt } }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.blue)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { withAnimation(.spring()) { viewState = .preferences } }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color.gray.opacity(0.15))
                
                // Separador moderno
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                
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
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(promptService.searchQuery.isEmpty ? "Crea tu primer prompt para comenzar" : "Intenta con otros términos de búsqueda")
                                .font(.system(size: 14))
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
                                        withAnimation(.spring()) { viewState = .detail(prompt) }
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
                usePrompt(prompt)
                // Cerrar preview si está abierto
                if showingPreview {
                    showingPreview = false
                }
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Métodos
    
    /// Usa un prompt (copia al clipboard) - Versión optimizada
    private func usePrompt(_ prompt: Prompt) {
        self.promptService.usePrompt(prompt)
        
        // Efectos de retroalimentación
        if self.preferences.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
        
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
