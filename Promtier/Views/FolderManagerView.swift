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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestionar Categorías")
                        .font(.system(size: 24, weight: .bold))
                    Text("Personaliza tu flujo de trabajo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Hecho") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            HStack(alignment: .top, spacing: 0) {
                // Lista de categorías unificada y premium
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(promptService.folders) { folder in
                                CategoryRow(
                                    folder: folder,
                                    isEditing: editingFolder?.id == folder.id,
                                    onEdit: { startEditing(folder) },
                                    onDelete: { promptService.deleteFolder(folder) }
                                )
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .frame(width: 250)
                .background(Color.primary.opacity(0.02))
                
                Divider()
                
                // Formulario de edición refinado
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: editingFolder == nil ? "plus.circle.fill" : "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text(editingFolder == nil ? "Nueva Categoría" : "Editar Categoría")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nombre de la Categoría")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.7))
                        
                        TextField("Ej: Marketing, Personal...", text: $newFolderName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icono")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            Button {
                                showingIconPicker = true
                            } label: {
                                Image(systemName: selectedIcon ?? "folder.fill")
                                    .font(.system(size: 20))
                                    .frame(width: 56, height: 56)
                                    .background(selectedColor.opacity(0.12))
                                    .foregroundColor(selectedColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: selectedColor.opacity(0.1), radius: 5, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            LazyVGrid(columns: [GridItem(.fixed(26)), GridItem(.fixed(26)), GridItem(.fixed(26)), GridItem(.fixed(26)), GridItem(.fixed(26))], spacing: 12) {
                                ForEach(presetColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                .shadow(radius: 2)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.3), value: selectedColor)
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if editingFolder != nil {
                            Button("Cancelar") {
                                resetForm()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                        
                        Button {
                            saveFolder()
                        } label: {
                            Text(editingFolder == nil ? "Crear Categoría" : "Guardar Cambios")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(newFolderName.isEmpty ? Color.gray.opacity(0.3) : selectedColor)
                                .cornerRadius(12)
                                .shadow(color: selectedColor.opacity(newFolderName.isEmpty ? 0 : 0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(newFolderName.isEmpty)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
            }
        }
        .frame(width: 700, height: 520)
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, color: selectedColor)
        }
    }
    
    private func startEditing(_ folder: Folder) {
        withAnimation(.spring()) {
            editingFolder = folder
            newFolderName = folder.name
            selectedIcon = folder.icon ?? "folder.fill"
            selectedColor = Color(hex: folder.displayColor)
        }
    }
    
    private func resetForm() {
        withAnimation(.spring()) {
            editingFolder = nil
            newFolderName = ""
            selectedColor = .blue
            selectedIcon = "folder.fill"
        }
    }
    
    private func saveFolder() {
        let hex = "#" + NSColor(selectedColor).hexString
        
        if let editing = editingFolder {
            let updated = Folder(id: editing.id, name: newFolderName, color: hex, icon: selectedIcon, createdAt: editing.createdAt, parentId: editing.parentId)
            _ = promptService.updateFolder(updated, oldName: editing.name)
        } else {
            let new = Folder(name: newFolderName, color: hex, icon: selectedIcon)
            _ = promptService.createFolder(new)
        }
        resetForm()
    }
}

// MARK: - Subviews Premium

struct CategoryRow: View {
    let folder: Folder
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: folder.displayColor).opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: folder.icon ?? "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: folder.displayColor))
            }
            
            Text(folder.name)
                .font(.system(size: 14, weight: isEditing ? .bold : .medium))
                .foregroundColor(isEditing ? .primary : .primary.opacity(0.8))
            
            Spacer()
            
            if isHovered || isEditing {
                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Editar categoría")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Eliminar categoría")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditing ? Color.blue.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
                .padding(.horizontal, 8)
        )
        .onHover { h in withAnimation(.easeInOut(duration: 0.2)) { isHovered = h } }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

#Preview {
    FolderManagerView()
        .environmentObject(PromptService())
}
