//
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct NewPromptView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var promptService: PromptServiceSimple
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var description = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var showingPreview = false
    
    // CONFIGURABLE: Modo edición
    @State private var editingPrompt: Prompt?
    
    init(prompt: Prompt? = nil) {
        self._editingPrompt = State(initialValue: prompt)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno con título y botón de cerrar
            HStack(spacing: 20) {
                Text(editingPrompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cancelar") {
                    dismiss()
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
                            
                            TextField("Descripción (opcional)", text: $description)
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
                            // Etiquetas
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Etiquetas")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    TextField("Nueva etiqueta", text: $tagInput)
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
                                    
                                    Button("Agregar") {
                                        addTag()
                                    }
                                    .disabled(tagInput.isEmpty)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(tagInput.isEmpty ? Color.gray : Color.blue)
                                    )
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Tags existentes
                                if !tags.isEmpty {
                                    LazyVGrid(columns: [
                                        GridItem(.adaptive(minimum: 100))
                                    ], spacing: 10) {
                                        ForEach(tags, id: \.self) { tag in
                                            HStack(spacing: 8) {
                                                Text(tag)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.blue)
                                                Spacer()
                                                Button(action: { removeTag(tag) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red.opacity(0.8))
                                                        .font(.system(size: 16))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // Carpetas
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Carpeta")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Picker("Carpeta", selection: $selectedFolder) {
                                    Text("Sin carpeta").tag(String?.none)
                                    ForEach(getAvailableFolders(), id: \.self) { folder in
                                        Text(folder).tag(folder as String?)
                                    }
                                }
                                .font(.system(size: 16))
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
                    
                    // Sección de vista previa
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Vista Previa")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !content.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Vista previa del contenido:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(content)
                                    .padding(16)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    .font(.system(size: 16))
                                
                                // Variables encontradas
                                let variables = extractTemplateVariables()
                                if !variables.isEmpty {
                                    Text("Variables encontradas: \(variables.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.top, 8)
                                }
                            }
                        } else {
                            Text("Agrega contenido para ver la vista previa")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Footer moderno con botones
            HStack(spacing: 12) {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(editingPrompt != nil ? "Guardar" : "Crear") {
                    savePrompt()
                }
                .disabled(title.isEmpty || content.isEmpty)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((title.isEmpty || content.isEmpty) ? Color.gray : Color.blue)
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 560, height: 480)
        .onAppear {
            if let prompt = editingPrompt {
                title = prompt.title
                content = prompt.content
                description = prompt.description ?? ""
                tags = prompt.tags
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
            }
        }
    }
    
    // MARK: - Métodos
    
    @State private var isSaving = false
    
    private func savePrompt() {
        isSaving = true
        
        let prompt = Prompt(
            title: title,
            content: content,
            description: description.isEmpty ? nil : description,
            tags: tags,
            folder: selectedFolder
        )
        
        if let editingPrompt = editingPrompt {
            // Actualizar prompt existente
            var updatedPrompt = prompt
            updatedPrompt.id = editingPrompt.id // Necesitamos poder asignar el ID
            updatedPrompt.createdAt = editingPrompt.createdAt
            updatedPrompt.modifiedAt = Date()
            updatedPrompt.useCount = editingPrompt.useCount
            updatedPrompt.isFavorite = isFavorite
            
            _ = promptService.updatePrompt(updatedPrompt)
        } else {
            // Crear nuevo prompt
            var newPrompt = prompt
            newPrompt.isFavorite = isFavorite
            _ = promptService.createPrompt(newPrompt)
        }
        
        dismiss()
    }
    
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            tagInput = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func getAvailableFolders() -> [String] {
        // Obtener carpetas existentes de los prompts
        let folders = Set(promptService.prompts.map { $0.folder }.compactMap { $0 })
        return Array(folders).sorted()
    }
    
    private func extractTemplateVariables() -> [String] {
        let pattern = "\\{\\{([^}]+)\\}\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: content.utf16.count)
        
        let matches = regex?.matches(in: content, options: [], range: range) ?? []
        return matches.compactMap {
            if let range = Range($0.range(at: 1), in: content) {
                return String(content[range])
            }
            return nil
        }
    }
}

#Preview {
    NewPromptView()
        .environmentObject(PromptServiceSimple())
        .environmentObject(PreferencesManager.shared)
}
