//
//  CategorySidebar.swift
//  Promtier
//
//  VISTA: Sidebar visual de categorías con colores y contadores
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

@preconcurrency struct SidebarDragPayload: Codable, Sendable {
    let kind: String
    let ids: [String]?
    let id: String?
}

struct CategorySidebar: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var batchService: BatchOperationsService
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @StateObject private var viewModel = CategorySidebarViewModel()
    
    private var categories: [PredefinedCategory] {
        PredefinedCategory.allCases
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header sutil
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isSystemSectionExpanded ? 90 : 0))
                    
                    Text("explore".localized(for: preferences.language))
                        .font(.system(size: (preferences.language == .spanish ? 10 : 11) * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(viewModel.isHeaderHovered ? .primary : .secondary)
                        .textCase(.uppercase)
                        .tracking((preferences.language == .spanish ? 0.8 : 1.2) * preferences.fontSize.scale)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isSystemSectionExpanded.toggle()
                    }
                    HapticService.shared.playLight()
                }
                .onHover { viewModel.isHeaderHovered = $0 }
                
                Spacer()
                
                // Botones de Acción (Ordenamiento y Nueva Categoría)
                HStack(spacing: 4) {
                    // Botón de Ordenamiento de Prompts
                    Menu {
                        Button { promptService.promptSortMode = .name } label: {
                            Label("sort_name".localized(for: preferences.language), systemImage: promptService.promptSortMode == .name ? "checkmark" : "textformat.abc")
                        }
                        Button { promptService.promptSortMode = .newest } label: {
                            Label("sort_newest".localized(for: preferences.language), systemImage: promptService.promptSortMode == .newest ? "checkmark" : "calendar")
                        }
                        Button { promptService.promptSortMode = .mostUsed } label: {
                            Label("sort_most_used".localized(for: preferences.language), systemImage: promptService.promptSortMode == .mostUsed ? "checkmark" : "flame.fill")
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .foregroundColor(viewModel.isSortMenuHovered ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(viewModel.isSortMenuHovered ? 0.06 : 0))
                        )
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("sort_prompts_help".localized(for: preferences.language))
                    .onHover { viewModel.isSortMenuHovered = $0 }
                    
                    // Botón de Nueva Categoría
                    Button {
                        menuBarManager.folderToEdit = nil
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            menuBarManager.activeViewState = .folderManager
                        }
                        HapticService.shared.playLight()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.isAddFolderHovered ? .blue : .secondary)
                            .offset(y: -0.5) // Alineación visual perfecta
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(viewModel.isAddFolderHovered ? 0.06 : 0))
                            )
                            .contentShape(Rectangle())
                            .scaleEffect(viewModel.isAddFolderHovered ? 1.03 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isAddFolderHovered)
                    }
                    .buttonStyle(.plain)
                    .help("create_category".localized(for: preferences.language))
                    .onHover { viewModel.isAddFolderHovered = $0 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            if viewModel.isSystemSectionExpanded {
                VStack(spacing: 4) {
                    // Botón "Todas"
                    SidebarItem(
                        title: "all",
                        icon: "square.grid.2x2.fill",
                        color: .blue,
                        count: promptService.prompts.count,
                        isSelected: promptService.selectedCategory == nil
                    ) {
                        promptService.selectedCategory = nil
                    }
                    
                    // Botón "Recientes"
                    SidebarItem(
                        title: "recent",
                        icon: "clock.arrow.2.circlepath",
                        color: .purple,
                        count: viewModel.recentCount,
                        isSelected: promptService.selectedCategory == "recent"
                    ) {
                        promptService.selectedCategory = "recent"
                    }
                    
                    // Botón "Favoritos"
                    SidebarItem(
                        title: "favorites",
                        icon: "star.fill",
                        color: .yellow,
                        count: viewModel.favoritesCount,
                        isSelected: promptService.selectedCategory == "favorites",
                        isDropTarget: viewModel.isTargetedFavoritos,
                        action: {
                            promptService.selectedCategory = "favorites"
                        },
                        dropHandler: { promptId in
                            viewModel.markAsFavorite(id: promptId, promptService: promptService, batchService: batchService, preferences: preferences)
                        }
                    )
                    .onDrop(of: [.json, .plainText], isTargeted: $viewModel.isTargetedFavoritos) { providers in
                        viewModel.handleQuickDrop(providers: providers, to: "favorites", promptService: promptService, batchService: batchService, preferences: preferences)
                    }
                    
                    // Botón "Sin categoría"
                    SidebarItem(
                        title: "uncategorized",
                        icon: "folder.fill",
                        color: .gray,
                        count: viewModel.categoryCount(for: "uncategorized"),
                        isSelected: promptService.selectedCategory == "uncategorized",
                        isDropTarget: viewModel.isTargetedSinCategoria,
                        action: {
                            promptService.selectedCategory = "uncategorized"
                        },
                        dropHandler: { promptId in
                            viewModel.movePrompt(id: promptId, to: nil, promptService: promptService, batchService: batchService, preferences: preferences)
                        }
                    )
                    .onDrop(of: [.json, .plainText], isTargeted: $viewModel.isTargetedSinCategoria) { providers in
                        viewModel.handleQuickDrop(providers: providers, to: nil, promptService: promptService, batchService: batchService, preferences: preferences)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
            
            VStack(spacing: 0) {
                // Divider (Cleanup)
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                
                // Lista de categorías (Extraído para reducir complejidad)
                foldersListView
            }
            
            Spacer()
        }
        .onHover { hovering in
            menuBarManager.setSidebarHovered(hovering)
        }
        .onAppear {
            viewModel.refreshCounters(with: promptService.prompts)
        }
        .onReceive(promptService.$prompts) { prompts in
            viewModel.refreshCounters(with: prompts)
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
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.95)
                Color.primary.opacity(0.02)
            }
        )
    }
    
    @ViewBuilder
    private var foldersListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                
                // ── Pinned section ────────────────────────────────
                let pinnedFolders = promptService.folders.filter {
                    preferences.pinnedFolderNames.contains($0.name)
                }.sorted {
                    (preferences.pinnedFolderNames.firstIndex(of: $0.name) ?? 99) <
                    (preferences.pinnedFolderNames.firstIndex(of: $1.name) ?? 99)
                }
                
                if !pinnedFolders.isEmpty {
                    HStack {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("pinned".localized(for: preferences.language).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.4))
                            .tracking(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    
                    ForEach(pinnedFolders, id: \.id) { folder in
                        pinnedFolderRow(folder)
                    }
                    
                    Divider()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                }
                
                // ── Remaining folders ────────────────────────────
                let unpinnedFolders = promptService.folders.filter {
                    !preferences.pinnedFolderNames.contains($0.name)
                }
                
                ForEach(unpinnedFolders, id: \.id) { folder in
                    folderRow(folder)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .contextMenu {
            Button {
                menuBarManager.folderToEdit = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
                HapticService.shared.playLight()
            } label: {
                Label("create_category".localized(for: preferences.language), systemImage: "folder.badge.plus")
            }
        }
    }
    
    @ViewBuilder
    private func pinnedFolderRow(_ folder: Folder) -> some View {
        let count = viewModel.categoryCount(for: folder.name)
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: promptService.selectedCategory == folder.name,
            isPinned: true,
            action: { promptService.selectedCategory = folder.name },
            isEditable: true,
            rawTitle: folder.name,
            onRename: { newName in
                var updated = folder
                updated.name = newName
                _ = promptService.updateFolder(updated)
                if promptService.selectedCategory == folder.name {
                    promptService.selectedCategory = newName
                }
                if preferences.isPinned(folder.name) {
                    preferences.togglePin(folder.name)
                    preferences.togglePin(newName)
                }
            },
            onDoubleClickRow: {
                menuBarManager.folderToEdit = folder
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
            }
        )
        .transition(.move(edge: .leading).combined(with: .opacity))
        .contextMenu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    preferences.togglePin(folder.name)
                }
                HapticService.shared.playLight()
            } label: {
                Label("Quitar pin", systemImage: "pin.slash")
            }
            
            Divider()
            
            Button {
                menuBarManager.folderToEdit = folder
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
            } label: {
                Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
            }
        }
    }
    
    @ViewBuilder
    private func folderRow(_ folder: Folder) -> some View {
        let count = viewModel.categoryCount(for: folder.name)
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: promptService.selectedCategory == folder.name,
            isDropTarget: viewModel.dropTargetFolderId == folder.id && viewModel.draggedFolder == nil,
            isReorderTarget: viewModel.dropTargetFolderId == folder.id && viewModel.draggedFolder != nil,
            action: { promptService.selectedCategory = folder.name },
            isEditable: true,
            rawTitle: folder.name,
            onRename: { newName in
                var updated = folder
                updated.name = newName
                _ = promptService.updateFolder(updated)
                if promptService.selectedCategory == folder.name {
                    promptService.selectedCategory = newName
                }
            },
            onDoubleClickRow: {
                menuBarManager.folderToEdit = folder
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
            }
        )
        .transition(.move(edge: .leading).combined(with: .opacity))
        .onDrag {
            self.viewModel.draggedFolder = folder
            return NSItemProvider(object: folder.id.uuidString as NSString)
        }
        .onDrop(of: [.json, .plainText, .text], delegate: FolderSidebarDropDelegate(
            folder: folder,
            promptService: promptService,
            menuBarManager: menuBarManager,
            dropTargetFolderId: $viewModel.dropTargetFolderId,
            draggedFolder: $viewModel.draggedFolder,
            onPromptMove: { ids, folderName in
                viewModel.movePrompts(ids: ids, to: folderName, promptService: promptService, batchService: batchService, preferences: preferences)
            }
        ))
        .contextMenu {
            // Pin
            if preferences.pinnedFolderNames.count < 3 || preferences.isPinned(folder.name) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        preferences.togglePin(folder.name)
                    }
                    HapticService.shared.playLight()
                } label: {
                    Label(
                        preferences.isPinned(folder.name) ? "Quitar pin" : "Pinear categoría",
                        systemImage: preferences.isPinned(folder.name) ? "pin.slash" : "pin.fill"
                    )
                }
                Divider()
            }
            
            Button {
                menuBarManager.folderToEdit = folder
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
            } label: {
                Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
            }
            
            Button(role: .destructive) {
                viewModel.requestDelete(folder: folder, counts: viewModel.categoryCounts)
                if viewModel.folderToDelete == nil && !viewModel.showingDeleteAlert {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        _ = promptService.deleteFolder(folder)
                    }
                    HapticService.shared.playSuccess()
                }
            } label: {
                Label("delete".localized(for: preferences.language), systemImage: "trash")
            }
        }
    }
}

// MARK: - DropDelegate Combinado para Sidebar (Prompts + Reordenado)
struct FolderSidebarDropDelegate: DropDelegate {
    let folder: Folder
    let promptService: PromptService
    let menuBarManager: MenuBarManager
    @Binding var dropTargetFolderId: UUID?
    @Binding var draggedFolder: Folder?
    
    var onPromptMove: ([String], String) -> Void
    
    func dropEntered(info: DropInfo) {
        // Reordenado
        if let draggedFolder = draggedFolder, draggedFolder.id != folder.id {
            withAnimation(.easeInOut(duration: 0.2)) {
                dropTargetFolderId = folder.id
            }
            
            let from = promptService.folders.firstIndex(where: { $0.id == draggedFolder.id })
            let to = promptService.folders.firstIndex(where: { $0.id == folder.id })
            
            if let from = from, let to = to {
                var updated = promptService.folders
                updated.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                promptService.reorderFolders(updated)
            }
            return
        }
        
        // Mover Prompts
        if draggedFolder == nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                dropTargetFolderId = folder.id
            }
        }
    }
    
    func dropExited(info: DropInfo) {
        if dropTargetFolderId == folder.id {
            withAnimation(.easeInOut(duration: 0.2)) {
                dropTargetFolderId = nil
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.json, .plainText, .text])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        dropTargetFolderId = nil
        let wasDraggingFolder = draggedFolder != nil
        self.draggedFolder = nil
        
        if wasDraggingFolder { return true }
        
        let jsonType = UTType.json.identifier
        for provider in info.itemProviders(for: [.json, .plainText]) {
            if provider.hasItemConformingToTypeIdentifier(jsonType) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: jsonType) { data, _ in
                    Task { @MainActor in
                        guard let data,
                              let payload = try? JSONDecoder().decode(SidebarDragPayload.self, from: data),
                              payload.kind == "promtier.prompt.ids",
                              let ids = payload.ids,
                              !ids.isEmpty else { return }
                        onPromptMove(ids, folder.name)
                    }
                }
                return true
            }
        }
        
        return true
    }
}

struct SidebarItem: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    var isDropTarget: Bool = false
    var isReorderTarget: Bool = false
    var isPinned: Bool = false
    let action: () -> Void
    
    var dropAllowed: Bool = true
    var dropHandler: ((String) -> Void)? = nil
    
    var isEditable: Bool = false
    var rawTitle: String? = nil
    var onRename: ((String) -> Void)? = nil
    var onDoubleClickRow: (() -> Void)? = nil
    var onDeleteSwipe: (() -> Void)? = nil
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    @State private var isEditingName = false
    @State private var editingName = ""
    @FocusState private var isFocused: Bool
    
    // Swipe-to-delete states
    @State private var dragOffset: CGFloat = 0
    @State private var isSwiping: Bool = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Fondo rojo de eliminación (oculto en el espacio desplazado)
            if onDeleteSwipe != nil && dragOffset < 0 {
                ZStack(alignment: .trailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                            isSwiping = false
                        }
                        onDeleteSwipe?()
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red)
                            .frame(width: 60)
                            .overlay(
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: -dragOffset)
                .clipped()
            }
            
            VStack(spacing: 0) {
                if isReorderTarget {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 2)
                        .cornerRadius(1)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12 * preferences.fontSize.scale, weight: .semibold))
                        .foregroundColor(isSelected ? .white : color.opacity(0.8))
                        .frame(width: 18 * preferences.fontSize.scale)
                    
                    if isEditingName {
                        TextField("", text: $editingName, onCommit: {
                            isEditingName = false
                            if !editingName.trimmingCharacters(in: .whitespaces).isEmpty, editingName != rawTitle {
                                onRename?(editingName)
                            }
                        })
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .font(.system(size: 13 * preferences.fontSize.scale, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                        .tint(.white)
                        .colorScheme(isSelected ? .dark : .light)
                        .onAppear {
                            isFocused = true
                        }
                    } else {
                        Text(title)
                            .font(.system(size: 13 * preferences.fontSize.scale, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                if isEditable, let raw = rawTitle {
                                    editingName = raw
                                    isEditingName = true
                                }
                            }
                            .onTapGesture(count: 1) {
                                if !isEditingName {
                                    HapticService.shared.playLight()
                                    action()
                                }
                            }
                    }
                    
                    Spacer()
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? .white.opacity(0.2) : Color.primary.opacity(0.05))
                            )
                    }
                    
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : color.opacity(0.5))
                            .rotationEffect(.degrees(45))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                    .shadow(color: preferences.isHaloEffectEnabled && isSelected ? Color.blue.opacity(0.25) : .clear, radius: 4, y: 2)
                    .overlay(
                        Group {
                            if isDropTarget {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .clipShape(
                                        .rect(
                                            topLeadingRadius: 10,
                                            bottomLeadingRadius: 10,
                                            bottomTrailingRadius: 0,
                                            topTrailingRadius: 0
                                        )
                                    )
                            }
                        }
                    )
            )
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        guard onDeleteSwipe != nil else { return }
                        if value.translation.width < 0 {
                            dragOffset = max(-60, value.translation.width)
                        } else if isSwiping && value.translation.width > 0 {
                            dragOffset = min(0, -60 + value.translation.width)
                        }
                    }
                    .onEnded { value in
                        guard onDeleteSwipe != nil else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.width < -30 {
                                dragOffset = -60
                                isSwiping = true
                            } else {
                                dragOffset = 0
                                isSwiping = false
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                if !isSwiping {
                    onDoubleClickRow?()
                }
            }
            .onTapGesture(count: 1) {
                if isSwiping {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                        isSwiping = false
                    }
                } else if !isEditingName {
                    HapticService.shared.playLight()
                    action()
                }
            }
        }
        .onHover { hovering in
            if !isSwiping {
                isHovered = hovering
            }
        }
    }
}
