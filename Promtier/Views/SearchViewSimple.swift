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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con búsqueda
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar prompts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
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
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
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
                    .onTapGesture {
                        usePrompt(prompt)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(width: 640, height: 480)
        .onAppear {
            // Filtrar prompts cuando cambia el texto de búsqueda
            promptService.searchQuery = searchText
        }
        .onChange(of: searchText) { newValue in
            promptService.searchQuery = newValue
        }
        .sheet(isPresented: $showingNewPrompt) {
            VStack {
                Text("Nuevo Prompt")
                    .font(.title2)
                Text("Funcionalidad de creación de prompts próximamente")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 400, height: 200)
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
}
