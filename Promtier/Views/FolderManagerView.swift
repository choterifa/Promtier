//
//  FolderManagerView.swift
//  Promtier
//
//  VISTA: Gestión de carpetas de organización
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct FolderManagerView: View {
    @EnvironmentObject var promptService: PromptService
    @Environment(\.dismiss) private var dismiss
    
    @State private var folders: [Folder] = []
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String? = "folder.fill"
    @State private var showingIconPicker = false
    @State private var editingFolder: Folder?
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gestionar Categorías")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Hecho") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            HStack(alignment: .top, spacing: 0) {
                // Lista de categorías única y unificada
                List {
                    ForEach(promptService.folders) { folder in
                        HStack {
                            Image(systemName: folder.icon ?? "folder.fill")
                                .foregroundColor(Color(hex: folder.displayColor))
                                .frame(width: 20)
                            
                            Text(folder.name)
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            // Acciones de edición rápida
                            HStack(spacing: 12) {
                                Button {
                                    startEditing(folder)
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    promptService.deleteFolder(folder)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 250)
                
                Divider()
                
                // Formulario de edición
                VStack(alignment: .leading, spacing: 20) {
                    Text(editingFolder == nil ? "Nueva Categoría" : "Editar Categoría")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ej: Marketing, Personal...", text: $newFolderName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icono")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                showingIconPicker = true
                            } label: {
                                Image(systemName: selectedIcon ?? "folder.fill")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(presetColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                        .shadow(radius: selectedColor == color ? 2 : 0)
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        if editingFolder != nil {
                            Button("Cancelar") {
                                resetForm()
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Spacer()
                        
                        Button(editingFolder == nil ? "Crear Categoría" : "Guardar Cambios") {
                            saveFolder()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newFolderName.isEmpty)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 650, height: 480)
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, color: selectedColor)
        }
    }
    
    private func startEditing(_ folder: Folder) {
        editingFolder = folder
        newFolderName = folder.name
        selectedIcon = folder.icon ?? "folder.fill"
        // Intentar parsear el color hex si existe
    }
    
    private func resetForm() {
        editingFolder = nil
        newFolderName = ""
        selectedColor = .blue
        selectedIcon = "folder.fill"
    }
    
    private func saveFolder() {
        let hexColor = selectedColor.hashValue.description // TODO: Helper para Hex
        // Por ahora usemos un mapeo simple de colores comunes o un helper
        let hex = "#" + NSColor(selectedColor).hexString
        
        if let editing = editingFolder {
            let updated = Folder(id: editing.id, name: newFolderName, color: hex, icon: selectedIcon, createdAt: editing.createdAt, parentId: editing.parentId)
            promptService.updateFolder(updated, oldName: editing.name)
        } else {
            let new = Folder(name: newFolderName, color: hex, icon: selectedIcon)
            promptService.createFolder(new)
        }
        resetForm()
    }
}

#Preview {
    FolderManagerView()
        .environmentObject(PromptService())
}
