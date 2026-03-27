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
    
    @State private var showingFolderManager = false
    @State private var dropTargetFolderId: UUID? = nil
    @State private var isTargetedFavoritos = false
    @State private var isTargetedSinCategoria = false
    
    // Reordenado (Sidebar)
    @State private var draggedFolder: Folder? = nil
    
    // Alerta de eliminación
    @State private var folderToDelete: Folder? = nil
    @State private var showingDeleteAlert = false
    
    // Header hover states
    @State private var isAddFolderHovered = false
    @State private var isSortMenuHovered = false
    @State private var isHeaderHovered = false
    @State private var isSystemSectionExpanded = true
    
    
    private var categories: [PredefinedCategory] {
        PredefinedCategory.allCases
    }
    
    private var categoryCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for prompt in promptService.prompts {
            let folder = prompt.folder ?? "uncategorized"
            counts[folder, default: 0] += 1
        }
        return counts
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header sutil
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isSystemSectionExpanded ? 90 : 0))
                    
                    Text("explore")
                        .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold))
                        .foregroundColor(isHeaderHovered ? .primary : .secondary)
                        .textCase(.uppercase)
                        .tracking(1.2 * preferences.fontSize.scale)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isSystemSectionExpanded.toggle()
                    }
                    HapticService.shared.playLight()
                }
                .onHover { isHeaderHovered = $0 }
                
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
                        .foregroundColor(isSortMenuHovered ? .primary : .secondary)
                        .scaleEffect(isSortMenuHovered ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSortMenuHovered)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("sort_prompts_help".localized(for: preferences.language))
                    .onHover { isSortMenuHovered = $0 }
                    
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
                            .foregroundColor(isAddFolderHovered ? .blue : .secondary)
                            .offset(y: -0.5) // Alineación visual perfecta
                            .scaleEffect(isAddFolderHovered ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAddFolderHovered)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(isAddFolderHovered ? 0.06 : 0))
                    )
                    .help("create_category".localized(for: preferences.language))
                    .onHover { isAddFolderHovered = $0 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
            
            if isSystemSectionExpanded {
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
                        count: promptService.prompts.filter { $0.lastUsedAt != nil }.count,
                        isSelected: promptService.selectedCategory == "recent"
                    ) {
                        promptService.selectedCategory = "recent"
                    }
                    
                    // Botón "Favoritos"
                    SidebarItem(
                        title: "favorites",
                        icon: "star.fill",
                        color: .yellow,
                        count: promptService.prompts.filter { $0.isFavorite }.count,
                        isSelected: promptService.selectedCategory == "favorites",
                        isDropTarget: isTargetedFavoritos,
                        action: {
                            promptService.selectedCategory = "favorites"
                        },
                        dropHandler: { promptId in
                            markAsFavorite(id: promptId)
                        }
                    )
                    .onDrop(of: [.json, .plainText], isTargeted: $isTargetedFavoritos) { providers in
                        handleQuickDrop(providers: providers, to: "favorites")
                    }
                    
                    // Botón "Sin categoría"
                    SidebarItem(
                        title: "uncategorized",
                        icon: "folder.fill",
                        color: .gray,
                        count: categoryCounts["uncategorized"] ?? 0,
                        isSelected: promptService.selectedCategory == "uncategorized",
                        isDropTarget: isTargetedSinCategoria,
                        action: {
                            promptService.selectedCategory = "uncategorized"
                        },
                        dropHandler: { promptId in
                            movePrompt(id: promptId, to: nil)
                        }
                    )
                    .onDrop(of: [.json, .plainText], isTargeted: $isTargetedSinCategoria) { providers in
                        handleQuickDrop(providers: providers, to: nil)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .clipped()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
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
                        Text("PINNED")
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
        let count: Int = categoryCounts[folder.name] ?? 0
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: promptService.selectedCategory == folder.name,
            isPinned: true,
            action: { promptService.selectedCategory = folder.name }
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
        let count: Int = categoryCounts[folder.name] ?? 0
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: promptService.selectedCategory == folder.name,
            isDropTarget: dropTargetFolderId == folder.id && draggedFolder == nil,
            isReorderTarget: dropTargetFolderId == folder.id && draggedFolder != nil,
            action: { promptService.selectedCategory = folder.name }
        )
        .transition(.move(edge: .leading).combined(with: .opacity))
        .onDrag {
            self.draggedFolder = folder
            return NSItemProvider(object: folder.id.uuidString as NSString)
        }
        .onDrop(of: [.json, .plainText, .text], delegate: FolderSidebarDropDelegate(
            folder: folder,
            promptService: promptService,
            menuBarManager: menuBarManager,
            dropTargetFolderId: $dropTargetFolderId,
            draggedFolder: $draggedFolder,
            onPromptMove: { ids, folderName in
                movePrompts(ids: ids, to: folderName)
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
            } label: {
                Label("delete".localized(for: preferences.language), systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helpers de Drag & Drop
    
    private func movePrompt(id: String, to folderName: String?) {
        guard let uuid = UUID(uuidString: id) else { return }
        movePrompts(ids: [uuid.uuidString], to: folderName)
    }

    private func movePrompts(ids: [String], to folderName: String?) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        _ = promptService.movePrompts(withIds: uuids, toFolder: folderName)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    private func markAsFavorite(ids: [String]) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        _ = promptService.markPromptsFavorite(withIds: uuids)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func markAsFavorite(id: String) {
        markAsFavorite(ids: [id])
    }

    private func moveToTrash(ids: [String]) {
        let uuids = ids.compactMap(UUID.init(uuidString:))
        guard !uuids.isEmpty else { return }
        _ = promptService.deletePrompts(withIds: uuids)
        if batchService.isSelectionModeActive, ids.count > 1 {
            batchService.clearSelection()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func decodeDraggedPromptIds(from provider: NSItemProvider, completion: @escaping ([String]) -> Void) -> Bool {
        let jsonType = UTType.json.identifier
        guard provider.hasItemConformingToTypeIdentifier(jsonType) else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: jsonType) { data, _ in
            Task { @MainActor in
                guard let data,
                      let payload = try? JSONDecoder().decode(SidebarDragPayload.self, from: data),
                      payload.kind == "promtier.prompt.ids",
                      let ids = payload.ids,
                      !ids.isEmpty else { return }
                completion(ids)
            }
        }
        return true
    }
    
    private func handleQuickDrop(providers: [NSItemProvider], to category: String?) -> Bool {
        for provider in providers {
            if decodeDraggedPromptIds(from: provider, completion: { ids in
                DispatchQueue.main.async {
                    if category == "favorites" {
                        markAsFavorite(ids: ids)
                    } else if category == "trash" {
                        moveToTrash(ids: ids)
                    } else {
                        movePrompts(ids: ids, to: category)
                    }
                }
            }) {
                return true
            }
        }
        return false
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
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
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
                
                Text(title)
                    .font(.system(size: 13 * preferences.fontSize.scale, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                    .lineLimit(1)
                
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
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: isDropTarget ? 2 : 0)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.shared.playLight()
            action()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
