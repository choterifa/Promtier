//
//  CategoryPillPicker.swift
//  Promtier
//
//  VISTA: Selector de categorías estilo píldora horizontal con animaciones
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct CategoryPillPicker: View {
    @Binding var selectedCategory: String?
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Text("category".localized(for: preferences.language).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            .padding(.horizontal, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Opción: Sin categoría / General
                    pillView(
                        title: "uncategorized".localized(for: preferences.language),
                        icon: "tag.slash.fill",
                        color: .gray,
                        isSelected: selectedCategory == nil
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedCategory = nil
                        }
                        HapticService.shared.playLight()
                    }
                    
                    // Categorías Predefinidas
                    ForEach(PredefinedCategory.allCases, id: \.self) { cat in
                        pillView(
                            title: cat.displayName,
                            icon: cat.icon,
                            color: cat.color,
                            isSelected: selectedCategory == cat.displayName
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedCategory = cat.displayName
                            }
                            HapticService.shared.playLight()
                        }
                    }
                    
                    // Carpetas Personalizadas del Usuario
                    ForEach(promptService.folders.filter { !PredefinedCategory.allCases.map { $0.displayName }.contains($0.name) }, id: \.id) { folder in
                        pillView(
                            title: folder.name,
                            icon: folder.icon ?? "folder.fill",
                            color: Color(hex: folder.displayColor),
                            isSelected: selectedCategory == folder.name
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedCategory = folder.name
                            }
                            HapticService.shared.playLight()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private func pillView(title: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .primary.opacity(0.7))
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(color)
                            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
