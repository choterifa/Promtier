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
    @EnvironmentObject var preferences: PreferencesManager
    var folderToEdit: Folder? = nil
    var onClose: () -> Void
    
    @State private var folders: [Folder] = []
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String? = "folder.fill"
    @State private var showingIconPicker = false
    @State private var editingFolder: Folder?
    @State private var animateColors = false
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                // Botón Colapsar Sidebar
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        preferences.showSidebar.toggle()
                    }
                }) {
                    Image(systemName: preferences.showSidebar ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(preferences.showSidebar ? .blue : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(preferences.showSidebar ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .help(preferences.showSidebar ? "Ocultar Categorías" : "Mostrar Categorías")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestionar Categorías")
                        .font(.system(size: 20 * preferences.fontSize.scale, weight: .bold))
                    Text("Personaliza tu flujo de trabajo")
                        .font(.system(size: 13 * preferences.fontSize.scale))
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
                if preferences.showSidebar {
                    // Lista de categorías - Ajustado para vista unificada
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(Array(promptService.folders.enumerated()), id: \.offset) { index, folder in
                                    CategoryRow(
                                        folder: folder,
                                        isEditing: editingFolder?.id == folder.id,
                                        onEdit: { startEditing(folder) },
                                        onDelete: { _ = promptService.deleteFolder(folder) }
                                    )
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .frame(width: max(160, min(280, preferences.windowWidth * 0.35)))
                    .background(Color.primary.opacity(0.01))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Divider()
                }
                
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
                            .onChange(of: newFolderName) { _, newValue in
                                if newValue.count > 40 {
                                    newFolderName = String(newValue.prefix(40))
                                }
                            }
                    }
                    
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icono")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            Button {
                                showingIconPicker = true
                            } label: {
                                Image(systemName: selectedIcon ?? "folder.fill")
                                    .font(.system(size: 20))
                                    .frame(width: 52, height: 52)
                                    .background(selectedColor.opacity(0.12))
                                    .foregroundColor(selectedColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedColor.opacity(0.2), lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.7))
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 24))], spacing: 12) {
                                ForEach(Array(presetColors.enumerated()), id: \.offset) { index, color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 2.5 : 0)
                                                .shadow(radius: 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.15 : (animateColors ? 1.0 : 0.6))
                                        .opacity(animateColors ? 1 : 0)
                                        .offset(x: animateColors ? 0 : -10)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.7)
                                            .delay(Double(index) * 0.04),
                                            value: animateColors
                                        )
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedColor = color
                                            }
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
        .onAppear {
            withAnimation {
                preferences.showSidebar = true
            }
            if let initialFolder = folderToEdit {
                startEditing(initialFolder)
            }
            
            // Animación de entrada para los colores (cascada de izq a dcha)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animateColors = true
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
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: preferences.windowWidth >= 620 ? 12 : 0) {
            if preferences.windowWidth >= 620 {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: folder.displayColor).opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: folder.icon ?? "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: folder.displayColor))
                }
            }
            
            Text(folder.name)
                .font(.system(size: 15 * preferences.fontSize.scale, weight: .semibold))
                .foregroundColor(isEditing ? .primary : .primary.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
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
    FolderManagerView(folderToEdit: nil, onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
