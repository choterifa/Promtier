 //
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import Foundation

struct NewPromptView: View {
    var onClose: () -> Void
    
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    
    // CONFIGURABLE: Modo edición
    @State private var editingPrompt: Prompt?
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self._editingPrompt = State(initialValue: prompt)
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno con título
            HStack(spacing: 20) {
                Text(editingPrompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido principal moderno
            ScrollView {
                VStack(spacing: 24) {
                    // Sección de información básica
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Información Básica")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            TextField("Título del prompt", text: $title)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Contenido del prompt...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 12)
                                        .padding(.leading, 16)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                TextEditor(text: $content)
                                    .frame(minHeight: 150)
                                    .font(.system(size: 16))
                                    .padding(16)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Sección de organización
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Organización")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            // Carpetas - Selector visual de categorías
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Categoría")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 6) {
                                    // Opción "Sin categoría"
                                    CategorySelectorButton(
                                        title: "Sin categoría",
                                        icon: "folder",
                                        color: .gray,
                                        isSelected: selectedFolder == nil
                                    ) {
                                        selectedFolder = nil
                                    }
                                    
                                    // Categorías predefinidas
                                    ForEach(PredefinedCategory.allCases, id: \.rawValue) { category in
                                        CategorySelectorButton(
                                            title: category.displayName,
                                            icon: category.icon,
                                            color: category.color,
                                            isSelected: selectedFolder == category.displayName
                                        ) {
                                            selectedFolder = category.displayName
                                        }
                                    }
                                }
                            }
                            
                            // Favorito
                            HStack(spacing: 12) {
                                Toggle("Marcar como favorito", isOn: $isFavorite)
                                    .font(.system(size: 16))
                                    .toggleStyle(SwitchToggleStyle())
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Footer moderno con botones
            HStack(spacing: 16) {
                Button("Cancelar") {
                    onClose()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.primary)
                
                Spacer()
                
                Button(editingPrompt != nil ? "Guardar Cambios" : "Crear Prompt") {
                    savePrompt()
                }
                .disabled(title.isEmpty || content.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .onAppear {
            if let prompt = editingPrompt {
                title = prompt.title
                content = prompt.content
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
            }
        }
    }
    
    // MARK: - Métodos
    
    @State private var isSaving = false
    
    private func savePrompt() {
        isSaving = true
        
        let newPrompt = Prompt(
            title: title,
            content: content,
            folder: selectedFolder
        )
        
        if let editingPrompt = editingPrompt {
            // Actualizar prompt existente - mantener ID original
            var updatedPrompt = newPrompt
            updatedPrompt.id = editingPrompt.id // Mantener el ID original
            updatedPrompt.isFavorite = isFavorite
            updatedPrompt.createdAt = editingPrompt.createdAt
            updatedPrompt.modifiedAt = Date()
            updatedPrompt.useCount = editingPrompt.useCount
            
            _ = promptService.updatePrompt(updatedPrompt)
        } else {
            // Crear nuevo prompt
            var newPrompt = newPrompt
            newPrompt.isFavorite = isFavorite
            _ = promptService.createPrompt(newPrompt)
        }
        
        onClose()
    }
    
    private func getAvailableFolders() -> [String] {
        let allFolders = promptService.getAllPrompts()
            .compactMap { $0.folder }
        let uniqueFolders = Array(Set(allFolders))
        return uniqueFolders.sorted()
    }
}

#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
