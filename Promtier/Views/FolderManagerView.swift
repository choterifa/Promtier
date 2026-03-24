//
//  FolderManagerView.swift
//  Promtier
//
//  VISTA: Gestión de carpetas de organización
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct FolderManagerView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    var folderToEdit: Folder? = nil
    var onClose: () -> Void
    
    @State private var folders: [Folder] = []
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .blue
    @State private var selectedIcon: String? = "folder.fill"
    @State private var showingIconPicker = false
    @State private var editingFolder: Folder?
    @State private var animateColors = false
    
    // Reordenado
    @State private var draggedFolder: Folder? = nil
    
    // Alerta de eliminación
    @State private var folderToDelete: Folder? = nil
    @State private var showingDeleteAlert = false
    
    private var categoryCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for prompt in promptService.prompts {
            let folder = prompt.folder ?? "uncategorized"
            counts[folder, default: 0] += 1
        }
        return counts
    }
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]
    
    var body: some View {
        ZStack {
            // Fondo Premium con gradientes
            backgroundView
            
            VStack(spacing: 0) {
                // Header Refinado
                headerView
                
                Divider().opacity(0.1)
                
                HStack(alignment: .top, spacing: 0) {
                    if preferences.showSidebar {
                        // Lista de categorías modernizada
                        sidebarListView
                            .frame(width: max(180, min(280, preferences.windowWidth * 0.38)))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        
                        Divider().opacity(0.1)
                    }
                    
                    // Contenido Principal (Formulario en Cards)
                    mainContentView
                }
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon, color: selectedColor)
        }
        .alert("delete_category_title".localized(for: preferences.language), isPresented: $showingDeleteAlert, presenting: folderToDelete) { folder in
            Button("delete".localized(for: preferences.language), role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    _ = promptService.deleteFolder(folder)
                }
                HapticService.shared.playSuccess()
            }
            Button("cancel".localized(for: preferences.language), role: .cancel) { }
        } message: { folder in
            let count = categoryCounts[folder.name] ?? 0
            Text(String(format: "delete_category_with_items_msg".localized(for: preferences.language), count))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                preferences.showSidebar = true
            }
            if let initialFolder = folderToEdit {
                startEditing(initialFolder)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animateColors = true
            }
        }
    }
    
    // MARK: - Components
    
    private var backgroundView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            
            if preferences.isHaloEffectEnabled {
                // Círculos decorativos para efecto mesh
                Circle()
                    .fill(selectedColor.opacity(0.04))
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(x: 200, y: -150)
                
                Circle()
                    .fill(Color.blue.opacity(0.02))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: -250, y: 200)
            }
        }
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    preferences.showSidebar.toggle()
                }
            }) {
                Image(systemName: preferences.showSidebar ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(preferences.showSidebar ? .blue : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(preferences.showSidebar ? Color.blue.opacity(0.1) : Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("manage_categories".localized(for: preferences.language))
                    .font(.system(size: 22 * preferences.fontSize.scale, weight: .bold))
                Text("customize_workflow".localized(for: preferences.language))
                    .font(.system(size: 13 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Text("done".localized(for: preferences.language))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        preferences.isHaloEffectEnabled ? 
                        AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]), startPoint: .top, endPoint: .bottom)) :
                        AnyShapeStyle(Color.blue)
                    )
                    .cornerRadius(10)
                    .shadow(color: preferences.isHaloEffectEnabled ? .blue.opacity(0.3) : .clear, radius: 5, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
    
    private var sidebarListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(promptService.folders) { folder in
                        CategoryRow(
                            folder: folder,
                            isEditing: editingFolder?.id == folder.id,
                            onEdit: { startEditing(folder) },
                            onDelete: {
                                let count = categoryCounts[folder.name] ?? 0
                                if count > 0 {
                                    folderToDelete = folder
                                    showingDeleteAlert = true
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        _ = promptService.deleteFolder(folder)
                                    }
                                    HapticService.shared.playSuccess()
                                }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .onDrag {
                            self.draggedFolder = folder
                            return NSItemProvider(object: folder.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: FolderReorderDelegate(
                            item: folder,
                            promptService: promptService,
                            draggedItem: $draggedFolder
                        ))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.primary.opacity(0.015))
    }
    
    private var mainContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Título de sección dinámica
                HStack(spacing: 12) {
                    Image(systemName: editingFolder == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(selectedColor)
                        .symbolEffect(.bounce, value: editingFolder != nil)
                    
                    Text(editingFolder == nil ? "new_category".localized(for: preferences.language) : "edit_category".localized(for: preferences.language))
                        .font(.system(size: 18, weight: .bold))
                }
                .padding(.top, 4)
                
                // Form Card
                VStack(spacing: 20) {
                    // Campo Nombre
                    VStack(alignment: .leading, spacing: 8) {
                        Text("name".localized(for: preferences.language).uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary.opacity(0.6))
                            .tracking(1)
                        
                        TextField("name_placeholder".localized(for: preferences.language), text: $newFolderName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            )
                    }
                    
                    HStack(alignment: .top, spacing: 24) {
                        // Selector de Icono
                        VStack(alignment: .leading, spacing: 8) {
                            Text("icon".localized(for: preferences.language).uppercased())
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary.opacity(0.6))
                                .tracking(1)
                            
                            Button {
                                showingIconPicker = true
                            } label: {
                                Image(systemName: selectedIcon ?? "folder.fill")
                                    .font(.system(size: 24))
                                    .frame(width: 58, height: 58)
                                    .background(
                                        ZStack {
                                            selectedColor.opacity(0.12)
                                            Circle().stroke(selectedColor.opacity(0.2), lineWidth: 1)
                                        }
                                    )
                                    .foregroundColor(selectedColor)
                                    .cornerRadius(16)
                                    .shadow(color: preferences.isHaloEffectEnabled ? selectedColor.opacity(0.1) : .clear, radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Selector de Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("color".localized(for: preferences.language).uppercased())
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary.opacity(0.6))
                                .tracking(1)
                            
                            colorPickerGrid
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(NSColor.textBackgroundColor).opacity(0.4))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1.1)
                )
                
                actionButtons
            }
            .padding(32)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
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
            menuBarManager.folderToEdit = nil
        }
    }
    
    private func revertChanges() {
        guard let folder = editingFolder else { return }
        withAnimation(.spring()) {
            newFolderName = folder.name
            selectedIcon = folder.icon ?? "folder.fill"
            selectedColor = Color(hex: folder.displayColor)
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
    
    private var colorPickerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28))], spacing: 14) {
            ForEach(Array(presetColors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    .scaleEffect(selectedColor == color ? 1.2 : (animateColors ? 1.0 : 0.4))
                    .opacity(animateColors ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.05), value: animateColors)
                    .onTapGesture {
                        HapticService.shared.playLight()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    }
            }
            
            // Color Picker Personalizado (Multicolor)
            ZStack {
                AngularGradient(
                    gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red]),
                    center: .center
                )
                .clipShape(Circle())
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: selectedColor != .gray ? 3 : 1)
                        .shadow(color: .black.opacity(0.1), radius: 2)
                )
                .scaleEffect(animateColors ? 1.0 : 0.4)
                .opacity(animateColors ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(presetColors.count) * 0.05), value: animateColors)

                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .opacity(0.011)
                    .frame(width: 28, height: 28)
                    .onTapGesture {
                        NSColorPanel.shared.makeKeyAndOrderFront(nil)
                    }
            }
        }
        .padding(.top, 4)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
                    if editingFolder != nil {
                        // Botón de "Nuevo" para salir de edición
                        Button {
                            resetForm()
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("new_category".localized(for: preferences.language))
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.blue.opacity(0.1)))
                    }
                    
                    Button {
                        if editingFolder == nil {
                            resetForm()
                        } else {
                            revertChanges()
                        }
                    } label: {
                        Text(editingFolder == nil ? "clear_form".localized(for: preferences.language) : "cancel".localized(for: preferences.language))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            
            Spacer()
            
            Button {
                saveFolder()
            } label: {
                HStack {
                    Text(editingFolder == nil ? "create".localized(for: preferences.language) : "save".localized(for: preferences.language))
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    newFolderName.isEmpty ? 
                        AnyShapeStyle(Color.gray.opacity(0.3)) : 
                        (preferences.isHaloEffectEnabled ? 
                            AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [selectedColor, selectedColor.opacity(0.8)]), startPoint: .top, endPoint: .bottom)) :
                            AnyShapeStyle(Color.blue))
                )
                .cornerRadius(12)
                .shadow(color: (preferences.isHaloEffectEnabled && !newFolderName.isEmpty) ? selectedColor.opacity(0.25) : .clear, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(newFolderName.isEmpty)
        }
        .padding(.top, 8)
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
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: folder.icon ?? "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: folder.displayColor))
                }
            }
            
            Text(folder.name)
                .font(.system(size: 15 * preferences.fontSize.scale, weight: .semibold))
                .foregroundColor(isEditing ? .primary : .primary.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            // Contenedor de acciones
            HStack(spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("delete_category".localized(for: preferences.language))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
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
// MARK: - Delegate para Reordenado
struct FolderReorderDelegate: DropDelegate {
    let item: Folder
    let promptService: PromptService
    @Binding var draggedItem: Folder?
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let from = promptService.folders.firstIndex(where: { $0.id == draggedItem.id }),
              let to = promptService.folders.firstIndex(where: { $0.id == item.id }) else { return }
        
        if promptService.folders[to].id != draggedItem.id {
            var updated = promptService.folders
            updated.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            promptService.reorderFolders(updated)
        }
    }
}
