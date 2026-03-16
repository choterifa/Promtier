//
//  CategorySidebar.swift
//  Promtier
//
//  VISTA: Sidebar visual de categorías con colores y contadores
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct CategorySidebar: View {
    @EnvironmentObject var promptService: PromptServiceSimple
    @Binding var selectedCategory: String?
    
    private var categories: [PredefinedCategory] {
        PredefinedCategory.allCases
    }
    
    private var categoryCounts: [PredefinedCategory: Int] {
        Dictionary(uniqueKeysWithValues: categories.map { category in
            let count = promptService.prompts.filter { $0.folder == category.displayName }.count
            return (category, count)
        })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("Categorías")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Botón "Todas"
                CategoryButton(
                    title: "Todas",
                    icon: "square.grid.2x2",
                    color: .gray,
                    count: promptService.prompts.count,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Lista de categorías
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(categories, id: \.rawValue) { category in
                        let count = categoryCounts[category] ?? 0
                        
                        CategoryButton(
                            title: category.displayName,
                            icon: category.icon,
                            color: category.color,
                            count: count,
                            isSelected: selectedCategory == category.displayName
                        ) {
                            selectedCategory = category.displayName
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 140) // Reducido de 200px a 140px
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 1)
    }
}

// MARK: - CategoryButton Component

struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icono con color
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                // Título
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Contador
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? color.opacity(0.8) : Color.gray.opacity(0.1))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack(spacing: 0) {
        CategorySidebar(selectedCategory: .constant(nil))
            .environmentObject(PromptServiceSimple())
        
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: 600, height: 400)
}
