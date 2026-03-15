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
            // Header moderno con búsqueda
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        TextField("Buscar prompts...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .onSubmit {
                                if let firstPrompt = promptService.filteredPrompts.first {
                                    usePrompt(firstPrompt)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { showingNewPrompt = true }) {
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
                        
                        Button(action: { showingPreferences = true }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido principal
            if promptService.filteredPrompts.isEmpty {
                VStack(spacing: 32) {
                    Spacer()
                    
                    Image(systemName: "text.bubble")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    VStack(spacing: 12) {
                        Text(searchText.isEmpty ? "No hay prompts aún" : "No se encontraron resultados")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(searchText.isEmpty ? "Crea tu primer prompt para comenzar" : "Intenta con otros términos de búsqueda")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if searchText.isEmpty {
                        Button("Crear Primer Prompt") {
                            showingNewPrompt = true
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
                                    selectedPrompt = prompt
                                },
                                onDoubleTap: {
                                    usePrompt(prompt)
                                },
                                onHover: { isHovering in
                                    hoveredPrompt = isHovering ? prompt : nil
                                }
                            )
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 560, height: 480) // Tamaño aumentado para mejor diseño
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
        .onKeyPress(.upArrow) {
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex > 0 {
                selectedPrompt = promptService.filteredPrompts[currentIndex - 1]
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) {
            if let currentPrompt = selectedPrompt,
               let currentIndex = promptService.filteredPrompts.firstIndex(where: { $0.id == currentPrompt.id }),
               currentIndex < promptService.filteredPrompts.count - 1 {
                selectedPrompt = promptService.filteredPrompts[currentIndex + 1]
                return .handled
            } else if promptService.filteredPrompts.isEmpty == false && selectedPrompt == nil {
                selectedPrompt = promptService.filteredPrompts.first
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if let prompt = selectedPrompt {
                usePrompt(prompt)
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
        
        // Sonido moderno de copia
        do {
            if preferences.soundEnabled {
                SoundService.shared.playCopySound()
            }
        } catch {
            print("Error al reproducir sonido: \(error)")
        }
    }
    
    /// Cambia el estado de favorito de un prompt
    private func toggleFavorite(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        _ = promptService.updatePrompt(updatedPrompt)
        
        // Sonido sutil de interacción
        if preferences.soundEnabled {
            SoundService.shared.playInteractionSound()
        }
    }
    
    /// Elimina un prompt
    private func deletePrompt(_ prompt: Prompt) {
        _ = promptService.deletePrompt(prompt)
    }
}
