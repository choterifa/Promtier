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
    
    @StateObject private var viewModel = FolderManagerViewModel()
    
    var folderToEdit: Folder? = nil
    var onClose: () -> Void
    
    // Reordenado
    @State private var draggedFolder: Folder? = nil
    @State private var dropTargetFolder: Folder? = nil
    
    @FocusState private var isNameFocused: Bool
    
    // Hover States
    @State private var isSidebarHovered = false
    @State private var isDoneHovered = false
    @State private var isIconHovered = false
    @State private var isNewHovered = false
    @State private var isClearHovered = false
    @State private var isCreateHovered = false
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]

    struct ParentOption: Identifiable {
        let folder: Folder
        let depth: Int
        var id: UUID { folder.id }

        var displayName: String {
            if depth == 0 { return folder.name }
            let prefix = String(repeating: "—", count: depth)
            return "\(prefix) \(folder.name)"
        }
    }

    private var availableParents: [ParentOption] {
        var options: [ParentOption] = []
        var visited: Set<UUID> = []

        func traverse(parentId: UUID?, currentDepth: Int) {
            let children = promptService.folders.filter { $0.parentId == parentId }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            for child in children {
                if let editingId = viewModel.editingFolder?.id, child.id == editingId { continue }
                if visited.contains(child.id) { continue }
                if currentDepth >= 2 { continue } // Max 2 levels total (0...1 for parents, creating depth 2 children)

                visited.insert(child.id)
                options.append(ParentOption(folder: child, depth: currentDepth))
                traverse(parentId: child.id, currentDepth: currentDepth + 1)
            }
        }

        traverse(parentId: nil, currentDepth: 0)
        return options
    }

    var body: some View {        ZStack {
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
        .sheet(isPresented: $viewModel.showingIconPicker) {
            IconPickerView(selectedIcon: $viewModel.selectedIcon, color: viewModel.selectedColor, categoryName: viewModel.newFolderName)
        }
        .alert("delete_category_title".localized(for: preferences.language), isPresented: $viewModel.showingDeleteAlert, presenting: viewModel.folderToDelete) { folder in
            Button("delete".localized(for: preferences.language), role: .destructive) {
                viewModel.confirmDelete(promptService: promptService)
            }
            Button("cancel".localized(for: preferences.language), role: .cancel) { }
        } message: { folder in
            let count = viewModel.categoryCount(for: folder.name)
            Text(String(format: "delete_category_with_items_msg".localized(for: preferences.language), count))
        }
        .alert("duplicate_category_title".localized(for: preferences.language), isPresented: $viewModel.showingDuplicateAlert) {
            Button("done".localized(for: preferences.language), role: .cancel) { }
        } message: {
            Text("duplicate_category_msg".localized(for: preferences.language))
        }
        .alert("duplicate_category_title".localized(for: preferences.language), isPresented: $viewModel.showingReservedNameAlert) {
            Button("done".localized(for: preferences.language), role: .cancel) { }
        } message: {
            Text("reserved_name_msg".localized(for: preferences.language))
        }
        .onAppear {
            viewModel.refreshCounters(with: promptService.prompts)

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                preferences.showSidebar = true
            }
            if let initialFolder = folderToEdit {
                viewModel.startEditing(initialFolder)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFocused = true
                viewModel.animateColors = true
            }
        }
        .onReceive(promptService.$prompts) { prompts in
            viewModel.refreshCounters(with: prompts)
        }
    }
    
    // MARK: - Components
    
    private var backgroundView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            
            if preferences.isHaloEffectEnabled {
                // Círculos decorativos para efecto mesh
                Circle()
                    .fill(viewModel.selectedColor.opacity(0.04))
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
                            .fill(preferences.showSidebar ? Color.blue.opacity(isSidebarHovered ? 0.15 : 0.1) : Color.primary.opacity(isSidebarHovered ? 0.08 : 0.04))
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.spring(response: 0.3)) { isSidebarHovered = h } }
            
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
                        AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [.blue.opacity(isDoneHovered ? 1.0 : 0.9), .blue.opacity(0.8)]), startPoint: .top, endPoint: .bottom)) :
                        AnyShapeStyle(Color.blue)
                    )
                    .cornerRadius(10)
                    .shadow(color: preferences.isHaloEffectEnabled ? .blue.opacity(isDoneHovered ? 0.4 : 0.3) : .clear, radius: isDoneHovered ? 8 : 5, y: isDoneHovered ? 3 : 2)
            }
            .buttonStyle(.plain)
            .onHover { h in withAnimation(.spring(response: 0.3)) { isDoneHovered = h } }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
    
    private var sidebarListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(promptService.folders) { folder in
                        CategoryRow(
                            folder: folder,
                            isEditing: viewModel.editingFolder?.id == folder.id,
                            isDropTarget: dropTargetFolder?.id == folder.id,
                            onEdit: { viewModel.startEditing(folder) },
                            onDelete: {
                                viewModel.requestDelete(folder: folder)
                                if viewModel.folderToDelete == nil && !viewModel.showingDeleteAlert {
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
                            draggedItem: $draggedFolder,
                            dropTarget: $dropTargetFolder
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
                    Image(systemName: viewModel.editingFolder == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(viewModel.selectedColor)
                        .symbolEffect(.bounce, value: viewModel.editingFolder != nil)
                    
                    Text(viewModel.editingFolder == nil ? "new_category".localized(for: preferences.language) : "edit_category".localized(for: preferences.language))
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
                        
                        TextField("name_placeholder".localized(for: preferences.language), text: $viewModel.newFolderName)
                            .textFieldStyle(.plain)
                            .focused($isNameFocused)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            )
                            .onChange(of: viewModel.newFolderName) { _, newValue in
                                if newValue.count > 30 {
                                    viewModel.newFolderName = String(newValue.prefix(30))
                                }
                            }
                            .onSubmit {
                                if !viewModel.newFolderName.isEmpty {
                                    viewModel.saveFolder(promptService: promptService, preferences: preferences) {
                                        isNameFocused = true
                                    }
                                }
                            }
                    }
                    
                    HStack(alignment: .top, spacing: 24) {
                        // Selector de Icono
                        VStack(alignment: .leading, spacing: 8) {
                            Text("icon".localized(for: preferences.language).uppercased())
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary.opacity(0.6))
                                .tracking(1)
                            
                            Button {
                                viewModel.showingIconPicker = true
                            } label: {
                                Image(systemName: viewModel.selectedIcon ?? "folder.fill")
                                    .font(.system(size: 24))
                                    .frame(width: 58, height: 58)
                                    .background(
                                        ZStack {
                                            viewModel.selectedColor.opacity(0.12)
                                            RoundedRectangle(cornerRadius: 16).stroke(viewModel.selectedColor.opacity(0.2), lineWidth: 1)
                                        }
                                    )
                                    .foregroundColor(viewModel.selectedColor)
                                    .cornerRadius(16)
                                    .shadow(color: preferences.isHaloEffectEnabled ? viewModel.selectedColor.opacity(isIconHovered ? 0.2 : 0.1) : .clear, radius: isIconHovered ? 12 : 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .onHover { h in withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isIconHovered = h } }
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

                    // Selector de Categoría Padre (Subcategorías)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("parent_category".localized(for: preferences.language).uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary.opacity(0.6))
                            .tracking(1)
                        
                        Picker("", selection: $viewModel.selectedParentId) {
                            Text("none".localized(for: preferences.language)).tag(UUID?.none)
                            ForEach(availableParents) { option in
                                Text(option.displayName).tag(UUID?.some(option.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
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
    
    private var colorPickerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28))], spacing: 14) {
            ForEach(Array(presetColors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 3 : 0)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    .scaleEffect(viewModel.selectedColor == color ? 1.2 : (viewModel.animateColors ? 1.0 : 0.4))
                    .opacity(viewModel.animateColors ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.05), value: viewModel.animateColors)
                    .onTapGesture {
                        HapticService.shared.playLight()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedColor = color
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
                        .stroke(Color.white, lineWidth: viewModel.selectedColor != .gray ? 3 : 1)
                        .shadow(color: .black.opacity(0.1), radius: 2)
                )
                .scaleEffect(viewModel.animateColors ? 1.0 : 0.4)
                .opacity(viewModel.animateColors ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(presetColors.count) * 0.05), value: viewModel.animateColors)

                ColorPicker("", selection: $viewModel.selectedColor)
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
                    if viewModel.editingFolder != nil {
                        // Botón de "Nuevo" para salir de edición
                        Button {
                            viewModel.resetForm(menuBarManager: menuBarManager)
                            isNameFocused = true
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
                        .background(Capsule().fill(Color.blue.opacity(isNewHovered ? 0.15 : 0.1)))
                        .onHover { h in withAnimation(.spring(response: 0.3)) { isNewHovered = h } }
                    }
                    
                    Button {
                        if viewModel.editingFolder == nil {
                            viewModel.resetForm(menuBarManager: menuBarManager)
                            isNameFocused = true
                        } else {
                            viewModel.revertChanges()
                        }
                    } label: {
                        Text(viewModel.editingFolder == nil ? "clear_form".localized(for: preferences.language) : "cancel".localized(for: preferences.language))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewModel.editingFolder == nil ? .red.opacity(0.8) : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(viewModel.editingFolder == nil ? Color.red.opacity(isClearHovered ? 0.18 : 0.12) : Color.primary.opacity(isClearHovered ? 0.08 : 0.05)))
                    .onHover { h in withAnimation(.spring(response: 0.3)) { isClearHovered = h } }
            
            Spacer()
            
            Button {
                viewModel.saveFolder(promptService: promptService, preferences: preferences) {
                    isNameFocused = true
                }
            } label: {
                HStack {
                    Text(viewModel.editingFolder == nil ? "create".localized(for: preferences.language) : "save".localized(for: preferences.language))
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    viewModel.newFolderName.isEmpty ? 
                        AnyShapeStyle(Color.gray.opacity(0.3)) : 
                        (preferences.isHaloEffectEnabled ? 
                            AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [viewModel.selectedColor, viewModel.selectedColor.opacity(0.8)]), startPoint: .top, endPoint: .bottom)) :
                            AnyShapeStyle(Color.blue))
                )
                .cornerRadius(12)
                .shadow(color: (preferences.isHaloEffectEnabled && !viewModel.newFolderName.isEmpty) ? viewModel.selectedColor.opacity(isCreateHovered ? 0.4 : 0.25) : .clear, radius: isCreateHovered ? 12 : 8, y: 4)
                .scaleEffect((isCreateHovered && !viewModel.newFolderName.isEmpty) ? 1.015 : 1.0)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.newFolderName.isEmpty)
            .onHover { h in withAnimation(.spring(response: 0.3)) { isCreateHovered = h } }
        }
        .padding(.top, 8)
    }
}

// MARK: - Subviews Premium

struct CategoryRow: View {
    let folder: Folder
    let isEditing: Bool
    let isDropTarget: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isDropTarget {
                Rectangle()
                    .fill(Color.blue)
                    .frame(height: 2)
                    .cornerRadius(1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
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
    @Binding var dropTarget: Folder?
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.dropTarget = nil
            self.draggedItem = nil
        }
        return true
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.dropTarget = nil
        }
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            self.dropTarget = item
        }
        
        guard let from = promptService.folders.firstIndex(where: { $0.id == draggedItem.id }),
              let to = promptService.folders.firstIndex(where: { $0.id == item.id }) else { return }
        
        if promptService.folders[to].id != draggedItem.id {
            var updated = promptService.folders
            updated.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            promptService.reorderFolders(updated)
        }
    }
}
