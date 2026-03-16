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
    var folderToEdit: Folder? = nil
    var onClose: () -> Void
    
    @State private var folders: [Folder] = []
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String? = "folder.fill"
    @State private var showingIconPicker = false
    @State private var editingFolder: Folder?
    @State private var isReady = false
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestionar Categorías")
                        .font(.system(size: 20, weight: .bold))
                    Text("Personaliza tu flujo de trabajo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Hecho") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            HStack(alignment: .top, spacing: 0) {
                // Lista de categorías - Ajustado para vista unificada
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(promptService.folders.enumerated()), id: \.offset) { index, folder in
                                CategoryRow(
                                    folder: folder,
                                    isEditing: editingFolder?.id == folder.id,
                                    onEdit: { startEditing(folder) },
                                    onDelete: { promptService.deleteFolder(folder) }
                                )
                                .scaleEffect(isReady ? 1.0 : 0.95)
                                .opacity(isReady ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.04),
                                    value: isReady
                                )
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .frame(width: 240)
                .background(Color.primary.opacity(0.02))
                
                Divider()
                
                // Formulario de edición refinado
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: editingFolder == nil ? "plus.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text(editingFolder == nil ? "Nueva Categoría" : "Editar Categoría")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .scaleEffect(isReady ? 1.0 : 0.9)
                    .opacity(isReady ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.08), value: isReady)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nombre")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.7))
                        
                        TextField("Ej: Marketing...", text: $newFolderName)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .scaleEffect(isReady ? 1.0 : 0.9)
                    .opacity(isReady ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.12), value: isReady)
                    
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icono")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            Button {
                                showingIconPicker = true
                            } label: {
                                Image(systemName: selectedIcon ?? "folder.fill")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .background(selectedColor.opacity(0.12))
                                    .foregroundColor(selectedColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .scaleEffect(isReady ? 1.0 : 0.9)
                        .opacity(isReady ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15), value: isReady)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            LazyVGrid(columns: [GridItem(.fixed(22)), GridItem(.fixed(22)), GridItem(.fixed(22)), GridItem(.fixed(22)), GridItem(.fixed(22))], spacing: 8) {
                                ForEach(Array(presetColors.enumerated()), id: \.offset) { index, color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 2.5 : 0)
                                                .shadow(radius: 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.15 : (isReady ? 1.0 : 0.5))
                                        .opacity(isReady ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.6)
                                            .delay(Double(index) * 0.03),
                                            value: isReady
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if editingFolder != nil {
                            Button("Cancelar") {
                                resetForm()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button {
                            saveFolder()
                        } label: {
                            Text(editingFolder == nil ? "Crear" : "Guardar")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(newFolderName.isEmpty ? Color.gray.opacity(0.3) : selectedColor)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(newFolderName.isEmpty)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, color: selectedColor)
        }
        .opacity(isReady ? 1 : 0)
        .onAppear {
            if let initialFolder = folderToEdit {
                startEditing(initialFolder)
            }
            
            // Sincronización fina: Esperamos a que la ventana se mueva un poco
            // antes de empezar el desvanecimiento y la cascada de elementos.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isReady = true
                }
            }
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            // Contenedor de acciones con ancho fijo para evitar saltos
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.blue.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Editar categoría")
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Eliminar categoría")
            }
            .opacity(isHovered || isEditing ? 1 : 0)
            .scaleEffect(isHovered || isEditing ? 1 : 0.9)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered || isEditing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditing ? Color.blue.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
                .padding(.horizontal, 12)
        )
        .onHover { h in withAnimation(.easeInOut(duration: 0.2)) { isHovered = h } }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

#Preview {
    FolderManagerView(folderToEdit: nil, onClose: {})
        .environmentObject(PromptService())
}
