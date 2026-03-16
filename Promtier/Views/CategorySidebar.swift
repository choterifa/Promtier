//
//  CategorySidebar.swift
//  Promtier
//
//  VISTA: Sidebar visual de categorías con colores y contadores
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct CategorySidebar: View {
    @EnvironmentObject var promptService: PromptService
    
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Spacer()
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
                
                // Botón "Favoritos" (Nuevo?) - No, mantengamos lo que hay pero mejorado
                
                // Botón "Sin categoría"
                SidebarItem(
                    title: "Sin categoría",
                    icon: "folder.fill",
                    color: .gray,
                    count: categoryCounts["Sin categoría"] ?? 0,
                    isSelected: promptService.selectedCategory == "Sin categoría"
                ) {
                    promptService.selectedCategory = "Sin categoría"
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            
            // Lista de categorías
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(categories, id: \.self) { category in
                        let count = categoryCounts[category.displayName] ?? 0
                        
                        SidebarItem(
                            title: category.displayName,
                            icon: category.icon,
                            color: category.color,
                            count: count,
                            isSelected: promptService.selectedCategory == category.displayName
                        ) {
                            promptService.selectedCategory = category.displayName
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
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : color.opacity(0.8))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
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
        }
        .buttonStyle(.plain)
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
