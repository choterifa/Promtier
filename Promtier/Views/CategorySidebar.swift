//
//  CategorySidebar.swift
//  Promtier
//
//  VISTA: Sidebar visual de categorías con colores y contadores
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

private struct SidebarDragPayload: Codable, Sendable {
    let kind: String
    let ids: [String]?
    let id: String?
}

struct CategorySidebar: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @State private var showingFolderManager = false
    @State private var draggedFolder: Folder? = nil
    @State private var dropTargetFolderId: UUID? = nil
    @State private var isTargetedFavoritos = false
    @State private var isTargetedSinCategoria = false
    @State private var isTargetedPapelera = false
    @EnvironmentObject var menuBarManager: MenuBarManager
    
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
            HStack {
                Text("explore")
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2 * preferences.fontSize.scale)
                
                Spacer()
                
                // Botón de Ordenamiento de Prompts (Redirigido desde cabecera principal)
                Menu {
                    Button { promptService.promptSortMode = .manual } label: {
                        Label("sort_manual".localized(for: preferences.language), systemImage: promptService.promptSortMode == .manual ? "checkmark" : "clock")
                    }
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
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("sort_prompts_help".localized(for: preferences.language))
                .padding(.trailing, 4)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        menuBarManager.activeViewState = .folderManager
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("manage_categories".localized(for: preferences.language))
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
            
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
            
            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            
            // Lista de categorías
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(promptService.folders) { folder in
                        let count = categoryCounts[folder.name] ?? 0
                        
                        SidebarItem(
                            title: LocalizedStringKey(folder.name),
                            icon: folder.icon ?? "folder.fill",
                            color: Color(hex: folder.displayColor),
                            count: count,
                            isSelected: promptService.selectedCategory == folder.name,
                            isDropTarget: dropTargetFolderId == folder.id && draggedFolder == nil,
                            action: {
                                promptService.selectedCategory = folder.name
                            }
                        )
                        .overlay(
                            VStack {
                                if dropTargetFolderId == folder.id && draggedFolder != nil {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(height: 2)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .offset(y: -2)
                        )
                        .onDrag {
                            self.draggedFolder = folder
                            menuBarManager.isModalActive = true // Evitar cierre automático
                            let provider = NSItemProvider()
                            let payload = SidebarDragPayload(kind: "promtier.folder.id", ids: nil, id: folder.id.uuidString)
                            if let data = try? JSONEncoder().encode(payload) {
                                provider.registerDataRepresentation(forTypeIdentifier: UTType.json.identifier, visibility: .all) { completion in
                                    completion(data, nil)
                                    return nil
                                }
                            }
                            return provider
                        }
                        .onDrop(of: [.json, .plainText], delegate: FolderDropDelegate(
                            folder: folder,
                            promptService: promptService,
                            menuBarManager: menuBarManager,
                            draggedFolder: $draggedFolder,
                            dropTargetFolderId: $dropTargetFolderId,
                            onMove: { source, dest in reorderFolder(source, to: dest) },
                            onPromptMove: { pIds, fName in movePrompts(ids: pIds, to: fName) }
                        ))
                        .contextMenu {
                            Button {
                                menuBarManager.folderToEdit = folder
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    menuBarManager.activeViewState = .folderManager
                                }
                            } label: {
                                Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
                            }
                            
                            Button(role: .destructive) {
                                _ = promptService.deleteFolder(folder)
                            } label: {
                                Label("delete".localized(for: preferences.language), systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
            
            // Papelera (Acceso rápido inferior)
            SidebarItem(
                title: "trash",
                icon: "trash.fill",
                color: .red,
                count: promptService.trashedPrompts.count,
                isSelected: menuBarManager.activeViewState == .trash,
                isDropTarget: isTargetedPapelera
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .trash
                }
            }
            .onDrop(of: [.json, .plainText], isTargeted: $isTargetedPapelera) { providers in
                handleQuickDrop(providers: providers, to: "trash")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 198)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.95)
                Color.primary.opacity(0.02)
            }
        )
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
    
    private func markAsFavorite(id: String) {
        markAsFavorite(ids: [id])
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
            guard let data,
                  let payload = try? JSONDecoder().decode(SidebarDragPayload.self, from: data),
                  payload.kind == "promtier.prompt.ids",
                  let ids = payload.ids,
                  !ids.isEmpty else { return }
            completion(ids)
        }
        return true
    }
    
    private func reorderFolder(_ source: Folder, to destination: Folder) {
        var folders = promptService.folders
        guard let sourceIndex = folders.firstIndex(where: { $0.id == source.id }),
              let destIndex = folders.firstIndex(where: { $0.id == destination.id }) else { return }
        
        if sourceIndex == destIndex { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let folder = folders.remove(at: sourceIndex)
            folders.insert(folder, at: destIndex)
            promptService.reorderFolders(folders)
            
            // Forzar actualización de UI
            promptService.loadFolders()
        }
        
        self.draggedFolder = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    // Helper para los botones superiores de drop
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

// MARK: - DropDelegate especializado para Carpeta
struct FolderDropDelegate: DropDelegate {
    let folder: Folder
    let promptService: PromptService
    let menuBarManager: MenuBarManager
    @Binding var draggedFolder: Folder?
    @Binding var dropTargetFolderId: UUID?
    
    var onMove: (Folder, Folder) -> Void
    var onPromptMove: ([String], String) -> Void
    
    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            dropTargetFolderId = folder.id
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
        // Si estamos arrastrando una carpeta para reordenar, usamos .move
        if draggedFolder != nil {
            return DropProposal(operation: .move)
        }
        // Si es un prompt siendo categorizado, usamos .copy para mostrar el "+"
        return DropProposal(operation: .copy)
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        if draggedFolder != nil { return true }
        return info.hasItemsConforming(to: [.json, .plainText])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        dropTargetFolderId = nil
        menuBarManager.isModalActive = false // Ya se puede cerrar
        
        // 1. Manejar reordenado de Carpeta
        if let dragged = draggedFolder {
            onMove(dragged, folder)
            draggedFolder = nil
            return true
        }
        
        // 2. Manejar movimiento de Prompt (JSON)
        let jsonType = UTType.json.identifier
        for provider in info.itemProviders(for: [.json, .plainText]) {
            if provider.hasItemConformingToTypeIdentifier(jsonType) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: jsonType) { data, _ in
                    guard let data,
                        let payload = try? JSONDecoder().decode(SidebarDragPayload.self, from: data),
                          payload.kind == "promtier.prompt.ids",
                          let ids = payload.ids,
                          !ids.isEmpty else { return }
                    DispatchQueue.main.async { onPromptMove(ids, folder.name) }
                }
                return true
            }
        }
        
        return false
    }
}

struct SidebarItem: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    var isDropTarget: Bool = false
    let action: () -> Void
    
    // Configuración opcional para Drop
    var dropAllowed: Bool = true
    var dropHandler: ((String) -> Void)? = nil
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14 * preferences.fontSize.scale, weight: .semibold))
                .foregroundColor(isSelected ? .white : color.opacity(0.8))
                .frame(width: 20 * preferences.fontSize.scale)
            
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.blue : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                .shadow(color: isSelected ? Color.blue.opacity(0.25) : .clear, radius: 4, y: 2)
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

#Preview {
    HStack(spacing: 0) {
        CategorySidebar()
            .environmentObject(PromptService())
        
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 600, height: 400)
}
