//
//  FolderManagerView.swift
//  Promtier
//
//  VISTA: Gestión de carpetas de organización
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct FolderManagerView: View {
    @EnvironmentObject var promptService: PromptServiceSimple
    @Environment(\.dismiss) private var dismiss
    
    @State private var folders: [String] = []
    @State private var newFolderName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingFolder: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno con título y botón de cerrar
            HStack(spacing: 20) {
                Text("Gestión de Carpetas")
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
            
            // Contenido principal moderno
            VStack(spacing: 20) {
                // Categorías predefinidas
                VStack(alignment: .leading, spacing: 16) {
                    Text("Categorías Predefinidas")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                        ForEach(PredefinedCategory.allCases, id: \.rawValue) { category in
                            let count = promptService.prompts.filter { $0.folder == category.displayName }.count
                            
                            PredefinedCategoryCard(
                                category: category,
                                promptCount: count
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Lista de carpetas personalizadas
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(getCustomFolders(), id: \.self) { folder in
                            FolderCard(
                                folder: folder,
                                promptCount: promptService.prompts.filter { $0.folder == folder }.count,
                                onEdit: {
                                    editingFolder = folder
                                    newFolderName = folder
                                },
                                onDelete: {
                                    deleteFolder(folder)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                
                // Sección moderna para agregar nueva carpeta
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 16) {
                        Text("Nueva Carpeta")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            TextField("Nombre de la nueva carpeta", text: $newFolderName)
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
                                addFolder()
                            }
                            .disabled(newFolderName.isEmpty)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newFolderName.isEmpty ? Color.gray : Color.blue)
                            )
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if editingFolder != nil {
                            VStack(spacing: 12) {
                                Text("Editar Carpeta")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    TextField("Nuevo nombre", text: $newFolderName)
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
                                    
                                    Button("Guardar") {
                                        updateFolder()
                                    }
                                    .disabled(newFolderName.isEmpty)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(newFolderName.isEmpty ? Color.gray : Color.blue)
                                    )
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button("Cancelar") {
                                        editingFolder = nil
                                        newFolderName = ""
                                    }
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
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 560, height: 480)
        .onAppear {
            loadFolders()
        }
        .alert("Información", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Métodos
    
    private func loadFolders() {
        let allFolders = Set(promptService.prompts.compactMap { $0.folder })
        let predefinedCategories = Set(PredefinedCategory.allCases.map { $0.displayName })
        folders = Array(allFolders.subtracting(predefinedCategories)).sorted()
    }
    
    private func getCustomFolders() -> [String] {
        let allFolders = Set(promptService.prompts.compactMap { $0.folder })
        let predefinedCategories = Set(PredefinedCategory.allCases.map { $0.displayName })
        return Array(allFolders.subtracting(predefinedCategories)).sorted()
    }
    
    private func addFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showAlert("El nombre de la carpeta no puede estar vacío")
            return
        }
        
        guard !folders.contains(trimmedName) else {
            showAlert("Ya existe una carpeta con ese nombre")
            return
        }
        
        folders.append(trimmedName)
        folders.sort()
        newFolderName = ""
        
        showAlert("Carpeta '\(trimmedName)' agregada correctamente")
    }
    
    private func updateFolder() {
        guard let editingFolder = editingFolder else { return }
        
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showAlert("El nombre de la carpeta no puede estar vacío")
            return
        }
        
        guard !folders.contains(trimmedName) || trimmedName == editingFolder else {
            showAlert("Ya existe una carpeta con ese nombre")
            return
        }
        
        // Actualizar todos los prompts que usan esta carpeta
        for i in 0..<promptService.prompts.count {
            if promptService.prompts[i].folder == editingFolder {
                promptService.prompts[i].folder = trimmedName
            }
        }
        
        // Actualizar lista de carpetas
        if let index = folders.firstIndex(of: editingFolder) {
            folders[index] = trimmedName
        }
        folders.sort()
        
        self.editingFolder = nil
        newFolderName = ""
        
        showAlert("Carpeta renombrada correctamente")
    }
    
    private func deleteFolder(_ folder: String) {
        let promptsInFolder = promptService.prompts.filter { $0.folder == folder }
        
        if !promptsInFolder.isEmpty {
            showAlert("No se puede eliminar la carpeta '\(folder)' porque contiene \(promptsInFolder.count) prompts")
            return
        }
        
        folders.removeAll { $0 == folder }
        showAlert("Carpeta '\(folder)' eliminada correctamente")
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            deleteFolder(folder)
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Componente FolderCard

struct FolderCard: View {
    let folder: String
    let promptCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder")
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(promptCount) \(promptCount == 1 ? "prompt" : "prompts")")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Contador visual
            Text("\(promptCount)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Botón de acciones
            Menu {
                Button("Editar nombre", action: onEdit)
                
                Button("Ver prompts", role: nil) {
                    // TODO: Implementar navegación a prompts de esta carpeta
                }
                
                Divider()
                
                Button("Eliminar", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    FolderManagerView()
        .environmentObject(PromptServiceSimple())
}
