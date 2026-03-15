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
            // Header con título y botón de cerrar
            HStack {
                Text(editingPrompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Formulario sin NavigationView
            ScrollView {
                Form {
                    // Sección de información básica
                    Section(header: Text("Información Básica")
                        .font(.headline)
                        .padding(.top, 10)) {
                        TextField("Título del prompt", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                        
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("Contenido del prompt...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 12)
                                    .padding(.leading, 8)
                                    .font(.body)
                            }
                            
                            TextEditor(text: $content)
                                .frame(minHeight: 150) // Aumentado altura
                                .font(.body)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        
                        TextField("Descripción (opcional)", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    .padding(.horizontal, 20)
                    
                    // Sección de organización
                    Section(header: Text("Organización")
                        .font(.headline)
                        .padding(.top, 10)) {
                        // Etiquetas
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Etiquetas")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                TextField("Nueva etiqueta", text: $tagInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                                
                                Button("Agregar") {
                                    addTag()
                                }
                                .disabled(tagInput.isEmpty)
                                .buttonStyle(.borderedProminent)
                            }
                            
                            // Tags existentes
                            if !tags.isEmpty {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 100))
                                ], spacing: 10) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 8) {
                                            Text(tag)
                                                .font(.body)
                                            Spacer()
                                            Button(action: { removeTag(tag) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
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
                        Picker("Carpeta", selection: $selectedFolder) {
                            Text("Sin carpeta").tag(String?.none)
                            ForEach(getAvailableFolders(), id: \.self) { folder in
                                Text(folder).tag(folder as String?)
                            }
                        }
                        .font(.body)
                        
                        // Favorito
                        Toggle("Marcar como favorito", isOn: $isFavorite)
                            .font(.body)
                    }
                    .padding(.horizontal, 20)
                    
                    // Sección de vista previa
                    Section(header: Text("Vista Previa")
                        .font(.headline)
                        .padding(.top, 10)) {
                        if !content.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Vista previa del contenido:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(content)
                                    .padding(16)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .font(.body)
                                
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
                                .font(.body)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            
            // Footer con botones
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(editingPrompt != nil ? "Guardar" : "Crear") {
                    savePrompt()
                }
                .disabled(title.isEmpty || content.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400) // Tamaño uniforme compacto
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
