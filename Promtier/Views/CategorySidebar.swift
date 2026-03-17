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
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    private var categories: [PredefinedCategory] {
        PredefinedCategory.allCases
    }
    
    private var categoryCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for prompt in promptService.prompts {
            let folder = prompt.folder ?? "Sin categoría"
            counts[folder, default: 0] += 1
        }
        return counts
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header sutil
            HStack {
                Text("Explorar")
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
                .help("Gestionar Categorías")
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
            
            VStack(spacing: 4) {
                // Botón "Todas"
                SidebarItem(
                    title: "Todas",
                    icon: "square.grid.2x2.fill",
                    color: .blue,
                    count: promptService.prompts.count,
                    isSelected: promptService.selectedCategory == nil
                ) {
                    promptService.selectedCategory = nil
                }
                
                // Botón "Recientes"
                SidebarItem(
                    title: "Recientes",
                    icon: "clock.arrow.2.circlepath",
                    color: .purple,
                    count: promptService.prompts.filter { $0.lastUsedAt != nil }.count,
                    isSelected: promptService.selectedCategory == "Recientes"
                ) {
                    promptService.selectedCategory = "Recientes"
                }
                
                // Botón "Favoritos"
                SidebarItem(
                    title: "Favoritos",
                    icon: "star.fill",
                    color: .yellow,
                    count: promptService.prompts.filter { $0.isFavorite }.count,
                    isSelected: promptService.selectedCategory == "Favoritos",
                    action: {
                        promptService.selectedCategory = "Favoritos"
                    },
                    dropHandler: { promptId in
                        markAsFavorite(id: promptId)
                    }
                )
                
                // Botón "Sin categoría"
                SidebarItem(
                    title: "Sin categoría",
                    icon: "folder.fill",
                    color: .gray,
                    count: categoryCounts["Sin categoría"] ?? 0,
                    isSelected: promptService.selectedCategory == "Sin categoría",
                    action: {
                        promptService.selectedCategory = "Sin categoría"
                    },
                    dropHandler: { promptId in
                        movePrompt(id: promptId, to: nil)
                    }
                )
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
                            title: folder.name,
                            icon: folder.icon ?? "folder.fill",
                            color: Color(hex: folder.displayColor),
                            count: count,
                            isSelected: promptService.selectedCategory == folder.name,
                            action: {
                                promptService.selectedCategory = folder.name
                            },
                            dropHandler: { promptId in
                                movePrompt(id: promptId, to: folder.name)
                            }
                        )
                        .contextMenu {
                            Button {
                                menuBarManager.folderToEdit = folder
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    menuBarManager.activeViewState = .folderManager
                                }
                            } label: {
                                Label("Editar", systemImage: "pencil")
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
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
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
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticService.shared.playLight()
            action()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrop(of: [.plainText], isTargeted: $isHovered) { providers in
            guard dropAllowed, let handler = dropHandler else { return false }
            
            for provider in providers {
                provider.loadObject(ofClass: NSString.self) { result, _ in
                    if let promptId = result as? String {
                        DispatchQueue.main.async {
                            handler(promptId)
                        }
                    }
                }
            }
            return true
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
