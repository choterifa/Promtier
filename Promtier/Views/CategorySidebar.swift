//
//  CategorySidebar.swift
//  Promtier
//
//  VISTA: Sidebar visual de categorías con colores y contadores
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct CategorySidebar: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var showingFolderManager = false
    @State private var draggedFolder: Folder? = nil
    @State private var dropTargetFolderId: UUID? = nil
    @State private var isTargetedFavoritos = false
    @State private var isTargetedSinCategoria = false
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    private var categories: [PredefinedCategory] {
        PredefinedCategory.allCases
    }
    
    private var categoryCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for prompt in promptService.prompts {
            let folder = prompt.folder ?? NSLocalizedString("uncategorized", comment: "")
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
                .help(NSLocalizedString("manage_categories", comment: ""))
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
                    isSelected: promptService.selectedCategory == "Recientes"
                ) {
                    promptService.selectedCategory = "Recientes"
                }
                
                // Botón "Favoritos"
                SidebarItem(
                    title: "favorites",
                    icon: "star.fill",
                    color: .yellow,
                    count: promptService.prompts.filter { $0.isFavorite }.count,
                    isSelected: promptService.selectedCategory == "Favoritos",
                    isDropTarget: isTargetedFavoritos,
                    action: {
                        promptService.selectedCategory = "Favoritos"
                    },
                    dropHandler: { promptId in
                        markAsFavorite(id: promptId)
                    }
                )
                .onDrop(of: [.promtierPromptId, .plainText], isTargeted: $isTargetedFavoritos) { providers in
                    handleQuickDrop(providers: providers, to: "Favoritos")
                }
                
                // Botón "Sin categoría"
                SidebarItem(
                    title: "uncategorized",
                    icon: "folder.fill",
                    color: .gray,
                    count: categoryCounts[NSLocalizedString("uncategorized", comment: "")] ?? 0,
                    isSelected: promptService.selectedCategory == "Sin categoría",
                    isDropTarget: isTargetedSinCategoria,
                    action: {
                        promptService.selectedCategory = "Sin categoría"
                    },
                    dropHandler: { promptId in
                        movePrompt(id: promptId, to: nil)
                    }
                )
                .onDrop(of: [.promtierPromptId, .plainText], isTargeted: $isTargetedSinCategoria) { providers in
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
                            provider.registerDataRepresentation(forTypeIdentifier: UTType.promtierFolderId.identifier, visibility: .all) { completion in
                                completion(folder.id.uuidString.data(using: .utf8), nil)
                                return nil
                            }
                            return provider
                        }
                        .onDrop(of: [.promtierFolderId, .promtierPromptId, .plainText], delegate: FolderDropDelegate(
                            folder: folder,
                            promptService: promptService,
                            menuBarManager: menuBarManager,
                            draggedFolder: $draggedFolder,
                            dropTargetFolderId: $dropTargetFolderId,
                            onMove: { source, dest in reorderFolder(source, to: dest) },
                            onPromptMove: { pId, fName in movePrompt(id: pId, to: fName) }
                        ))
                        .contextMenu {
                            Button {
                                menuBarManager.folderToEdit = folder
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    menuBarManager.activeViewState = .folderManager
                                }
                            } label: {
                                Label("Editar", systemImage: "square.and.pencil")
                            }
                            
                            Button(role: .destructive) {
                                _ = promptService.deleteFolder(folder)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 200)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.95)
                Color.primary.opacity(0.02)
            }
        )
    }
    
    // MARK: - Helpers de Drag & Drop
    
    private func movePrompt(id: String, to folderName: String?) {
        guard let uuid = UUID(uuidString: id),
              let prompt = promptService.prompts.first(where: { $0.id == uuid }) else { return }
        
        var updated = prompt
        updated.folder = folderName
        _ = promptService.updatePrompt(updated)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    private func markAsFavorite(id: String) {
        guard let uuid = UUID(uuidString: id),
              let prompt = promptService.prompts.first(where: { $0.id == uuid }) else { return }
        
        var updated = prompt
        updated.isFavorite = true
        _ = promptService.updatePrompt(updated)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
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
            // Primero intentar con el ID interno
            if provider.hasItemConformingToTypeIdentifier(UTType.promtierPromptId.identifier) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.promtierPromptId.identifier) { data, _ in
                    if let data = data, let id = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            if category == "Favoritos" {
                                markAsFavorite(id: id)
                            } else {
                                movePrompt(id: id, to: category)
                            }
                        }
                    }
                }
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
    var onPromptMove: (String, String) -> Void
    
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
        return info.hasItemsConforming(to: [.promtierFolderId, .promtierPromptId, .plainText])
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
        
        // 2. Manejar movimiento de Prompt
        for provider in info.itemProviders(for: [.promtierPromptId, .plainText]) {
            let internalId = UTType.promtierPromptId.identifier
            if provider.hasItemConformingToTypeIdentifier(internalId) {
                _ = provider.loadDataRepresentation(forTypeIdentifier: internalId) { data, _ in
                    if let data = data, let id = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async { onPromptMove(id, folder.name) }
                    }
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
