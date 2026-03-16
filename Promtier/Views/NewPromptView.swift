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
    var prompt: Prompt?
    var onClose: () -> Void
    
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var isSaving = false
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                        .font(.system(size: 24, weight: .bold))
                    Text(prompt != nil ? "Actualiza los detalles de tu prompt" : "Crea una nueva herramienta de productividad")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            Divider()
                .padding(.horizontal, 32)
            
            // Contenido Principal
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // SECCIÓN: Escritura
                    SettingsSection(title: "Contenido", icon: "pencil.and.outline") {
                        VStack(spacing: 0) {
                            TextField("Título del prompt", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            
                            Divider().padding(.leading, 20)
                            
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Escribe aquí el contenido de tu prompt...")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .font(.system(size: 14))
                                }
                                
                                TextEditor(text: $content)
                                    .font(.system(size: 14, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 120)
                            }
                        }
                    }
                    
                    // SECCIÓN: Organización
                    SettingsSection(title: "Organización", icon: "folder.fill") {
                        VStack(spacing: 0) {
                            SettingsRow("Favorito", subtitle: "Acceso rápido en la barra lateral") {
                                Toggle("", isOn: $isFavorite)
                                    .toggleStyle(.switch)
                            }
                            
                            Divider().padding(.leading, 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categoría")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        CategoryTag(title: "Sin categoría", icon: "folder", color: .gray, isSelected: selectedFolder == nil) {
                                            selectedFolder = nil
                                        }
                                        
                                        ForEach(PredefinedCategory.allCases, id: \.self) { category in
                                            CategoryTag(title: category.displayName, icon: category.icon, color: category.color, isSelected: selectedFolder == category.displayName) {
                                                selectedFolder = category.displayName
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
            
            // Acciones Inferiores
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    Button(action: onClose) {
                        Text("Cancelar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 100, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: savePrompt) {
                        Text(prompt != nil ? "Guardar" : "Crear")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                    .shadow(color: title.isEmpty || content.isEmpty ? .clear : .blue.opacity(0.3), radius: 4, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(title.isEmpty || content.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color.primary.opacity(0.02))
            }
        }
        .frame(width: 600, height: 500)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // Decoración sutil
                Circle()
                    .fill(Color.blue.opacity(0.02))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: -250, y: 200)
            }
        )
        .onAppear {
            if let prompt = prompt {
                title = prompt.title
                content = prompt.content
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
            }
        }
    }
    
    private func savePrompt() {
        isSaving = true
        
        if let existingPrompt = prompt {
            var updated = existingPrompt
            updated.title = title
            updated.content = content
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
        } else {
            var new = Prompt(title: title, content: content, folder: selectedFolder)
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
        }
        
        onClose()
    }
}

struct CategoryTag: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
