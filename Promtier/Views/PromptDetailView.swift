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
            // Header moderno con título y botón de cerrar
            HStack(spacing: 20) {
                Text("Detalles del Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cerrar") {
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
            
            // Contenido principal
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header principal moderno
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(prompt.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
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
                                .foregroundColor(.secondary)
                            
                            if let folder = prompt.folder {
                                Label(folder, systemImage: "folder")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatDate(prompt.modifiedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Contenido del prompt moderno
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contenido")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(prompt.content)
                            .font(.system(size: 18, design: .monospaced))
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    // Variables de plantilla moderno
                    if !extractedTemplateVariables.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Variables de Plantilla")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(extractedTemplateVariables, id: \.self) { variable in
                                    HStack {
                                        Text("{{\(variable)}}")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                        
                                        Spacer()
                                        
                                        TextField("Valor", text: binding(for: variable))
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .font(.system(size: 16))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(NSColor.controlBackgroundColor))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                            .frame(width: 200)
                                    }
                                }
                            }
                            
                            Button("Copiar con variables") {
                                copyWithVariables()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Metadatos moderno
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Metadatos")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Creado:")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(prompt.createdAt))
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Modificado:")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(prompt.modifiedAt))
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("ID:")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(prompt.id.uuidString.prefix(8) + "...")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
                .padding()
            }
            
            // Footer moderno con botones de acción
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
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
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button("Cerrar") {
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 560, height: 480)
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
        folder: "Trabajo"
    )
    
    PromptDetailView(prompt: samplePrompt)
        .environmentObject(PromptServiceSimple())
        .environmentObject(ClipboardService.shared)
        .environmentObject(PreferencesManager.shared)
}
