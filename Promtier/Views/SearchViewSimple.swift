//
//  SearchViewSimple.swift
//  Promtier
//
//  VISTA PRINCIPAL SIMPLIFICADA: Interfaz básica de búsqueda
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit

// VISTA PRINCIPAL SIMPLIFICADA: Búsqueda básica con resultados
struct SearchViewSimple: View {
    @EnvironmentObject var promptService: PromptServiceSimple
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var searchText = ""
    @State private var selectedPrompt: Prompt?
    @State private var showingPromptDetail = false
    @State private var showingNewPrompt = false
    @State private var showingPreferences = false
    @State private var showingPreview = false
    @State private var hoveredPrompt: Prompt?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con búsqueda
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title2)
                
                TextField("Buscar prompts...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                    .onSubmit {
                        if let firstPrompt = promptService.filteredPrompts.first {
                            usePrompt(firstPrompt)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                Button(action: { showingNewPrompt = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingPreferences = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Contenido principal
            if promptService.filteredPrompts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No hay prompts aún" : "No se encontraron resultados")
                        .font(.system(size: 18, weight: .medium))
                    
                    if searchText.isEmpty {
                        Button("Crear Primer Prompt") {
                            showingNewPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Lista de prompts
                List(promptService.filteredPrompts, id: \.id) { prompt in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(prompt.title)
                                .font(.system(size: 14, weight: .medium))
                            
                            Text(prompt.content)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if prompt.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedPrompt?.id == prompt.id ? Color.blue.opacity(0.2) : Color.clear)
                    )
                    .onHover { isHovering in
                        hoveredPrompt = isHovering ? prompt : nil
                    }
                    .onTapGesture(count: 1) {
                        selectedPrompt = prompt
                    }
                    .onTapGesture(count: 2) {
                        usePrompt(prompt)
                    }
                    .contextMenu {
                        Button("Copiar") {
                            usePrompt(prompt)
                        }
                        
                        Button("Ver detalles") {
                            selectedPrompt = prompt
                            showingPromptDetail = true
                        }
                        
                        Button("Editar") {
                            selectedPrompt = prompt
                            showingNewPrompt = true
                        }
                        
                        Divider()
                        
                        Button(prompt.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos") {
                            toggleFavorite(prompt)
                        }
                        
                        Button("Eliminar") {
                            deletePrompt(prompt)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(width: 500, height: 400) // Tamaño ajustado a 500x400
        .onKeyPress(.space) {
            if showingPreview {
                showingPreview = false
                return .handled
            } else if let prompt = selectedPrompt ?? hoveredPrompt {
                selectedPrompt = prompt
                showingPreview = true
                return .handled
            }
            return .ignored
        }
        .onAppear {
            // Filtrar prompts cuando cambia el texto de búsqueda
            promptService.searchQuery = searchText
        }
        .onChange(of: searchText) { newValue in
            promptService.searchQuery = newValue
        }
        .sheet(isPresented: $showingNewPrompt) {
            NewPromptView(prompt: selectedPrompt)
                .environmentObject(promptService)
                .environmentObject(preferences)
        }
        .sheet(isPresented: $showingPromptDetail) {
            if let prompt = selectedPrompt {
                PromptDetailView(prompt: prompt)
                    .environmentObject(promptService)
                    .environmentObject(ClipboardService.shared)
                    .environmentObject(preferences)
            }
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
                .environmentObject(preferences)
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
    
    // MARK: - Métodos
    
    /// Usa un prompt (copia al clipboard)
    private func usePrompt(_ prompt: Prompt) {
        promptService.usePrompt(prompt)
        
        // Efecto háptico - CONFIGURABLE: Acceso seguro a preferencias
        do {
            if preferences.hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            }
        } catch {
            print("Error al acceder a hapticFeedback: \(error)")
        }
        
        // Sonido - CONFIGURABLE: Acceso seguro a preferencias
        do {
            if preferences.soundEnabled {
                NSSound.beep()
            }
        } catch {
            print("Error al acceder a soundEnabled: \(error)")
        }
    }
    
    /// Cambia el estado de favorito de un prompt
    private func toggleFavorite(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        _ = promptService.updatePrompt(updatedPrompt)
    }
    
    /// Elimina un prompt
    private func deletePrompt(_ prompt: Prompt) {
        _ = promptService.deletePrompt(prompt)
    }
}
