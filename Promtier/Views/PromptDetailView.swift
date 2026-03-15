//
//  PromptDetailView.swift
//  Promtier
//
//  VISTA: Vista detallada de un prompt
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct PromptDetailView: View {
    let prompt: Prompt
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var promptService: PromptServiceSimple
    @EnvironmentObject var clipboardService: ClipboardService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var showingEditSheet = false
    @State private var showingVariableSheet = false
    @State private var templateVariables: [String: String] = [:]
    @State private var isProcessing = false
    
    // Variables calculadas
    private var extractedTemplateVariables: [String] {
        prompt.extractTemplateVariables()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con título y botón de cerrar
            HStack {
                Text("Detalles del Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cerrar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Contenido principal
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header principal
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(prompt.title)
                                .font(.system(size: 28, weight: .bold))
                            
                            Spacer()
                            
                            if prompt.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                            }
                        }
                        
                        if let description = prompt.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        
                        HStack(spacing: 20) {
                            Label("\(prompt.useCount) usos", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                            
                            if let folder = prompt.folder {
                                Label(folder, systemImage: "folder")
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(prompt.modifiedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Contenido del prompt
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contenido")
                            .font(.title2)
                        
                        Text(prompt.content)
                            .font(.system(size: 18, design: .monospaced)) // Texto más grande
                            .padding(20)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    
                    // Variables de plantilla
                    if !extractedTemplateVariables.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Variables de Plantilla")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(extractedTemplateVariables, id: \.self) { variable in
                                    HStack {
                                        Text("{{\(variable)}}")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        TextField("Valor", text: binding(for: variable))
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .frame(width: 200)
                                    }
                                }
                            }
                            
                            Button("Copiar con variables") {
                                copyWithVariables()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    // Etiquetas
                    if !prompt.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Etiquetas")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(prompt.tags, id: \.self) { tag in
                                    Text(tag)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    
                    // Metadatos
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadatos")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Creado:")
                                Spacer()
                                Text(formatDate(prompt.createdAt))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Modificado:")
                                Spacer()
                                Text(formatDate(prompt.modifiedAt))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("ID:")
                                Spacer()
                                Text(prompt.id.uuidString.prefix(8) + "...")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            
            // Footer con botones de acción
            HStack {
                Menu {
                    Button(action: { copyPrompt() }) {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: .command)
                    
                    Button(action: { copyWithVariables() }) {
                        Label("Copiar con variables", systemImage: "doc.text")
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    Button(action: { showingEditSheet = true }) {
                        Label("Editar", systemImage: "pencil")
                    }
                    .keyboardShortcut("e", modifiers: .command)
                    
                    Button(action: { toggleFavorite() }) {
                        Label(prompt.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos", 
                              systemImage: prompt.isFavorite ? "star" : "star.fill")
                    }
                    
                    Divider()
                    
                    Button(action: { deletePrompt() }) {
                        Label("Eliminar", systemImage: "trash")
                    }
                    .keyboardShortcut(.delete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cerrar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400) // Tamaño uniforme compacto
        .sheet(isPresented: $showingEditSheet) {
            NewPromptView(prompt: prompt)
                .environmentObject(promptService)
                .environmentObject(preferences)
        }
        .alert("Eliminar Prompt", isPresented: $isProcessing) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("¿Estás seguro de que deseas eliminar este prompt? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Métodos
    
    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { templateVariables[variable] ?? "" },
            set: { templateVariables[variable] = $0 }
        )
    }
    
    private func copyPrompt() {
        promptService.usePrompt(prompt)
        
        if preferences.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
        
        dismiss()
    }
    
    private func copyWithVariables() {
        var processedContent = prompt.content
        
        for (variable, value) in templateVariables {
            processedContent = processedContent.replacingOccurrences(of: "{{\(variable)}}", with: value)
        }
        
        clipboardService.copyToClipboard(processedContent)
        
        if preferences.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
        
        dismiss()
    }
    
    private func toggleFavorite() {
        var updatedPrompt = prompt
        updatedPrompt.isFavorite.toggle()
        _ = promptService.updatePrompt(updatedPrompt)
    }
    
    private func deletePrompt() {
        isProcessing = true
    }
    
    private func confirmDelete() {
        _ = promptService.deletePrompt(prompt)
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let samplePrompt = Prompt(
        title: "Code Review",
        content: "Por favor, revisa este código: {{codigo}}",
        description: "Plantilla para revisión de código",
        tags: ["coding", "review"],
        folder: "Trabajo"
    )
    
    PromptDetailView(prompt: samplePrompt)
        .environmentObject(PromptServiceSimple())
        .environmentObject(ClipboardService.shared)
        .environmentObject(PreferencesManager.shared)
}
