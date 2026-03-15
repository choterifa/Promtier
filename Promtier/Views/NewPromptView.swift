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
        NavigationView {
            Form {
                // Sección de información básica
                Section(header: Text("Información Básica")) {
                    TextField("Título del prompt", text: $title)
                    
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Contenido del prompt...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                    }
                    
                    TextField("Descripción (opcional)", text: $description)
                }
                
                // Sección de organización
                Section(header: Text("Organización")) {
                    // Etiquetas
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Etiquetas")
                            .font(.headline)
                        
                        HStack {
                            TextField("Nueva etiqueta", text: $tagInput)
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button("Agregar") {
                                addTag()
                            }
                            .disabled(tagInput.isEmpty)
                        }
                        
                        // Tags existentes
                        if !tags.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack {
                                        Text(tag)
                                        Spacer()
                                        Button(action: { removeTag(tag) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
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
                    
                    // Favorito
                    Toggle("Marcar como favorito", isOn: $isFavorite)
                }
                
                // Sección de vista previa
                Section(header: Text("Vista Previa")) {
                    if !content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vista previa del contenido:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(content)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            // Variables encontradas
                            let variables = extractTemplateVariables()
                            if !variables.isEmpty {
                                Text("Variables encontradas: \(variables.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Text("Agrega contenido para ver la vista previa")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(editingPrompt != nil ? "Editar Prompt" : "Nuevo Prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(editingPrompt != nil ? "Guardar" : "Crear") {
                        savePrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
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
        .frame(width: 600, height: 700)
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
