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
    var showLabel: Bool = true
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var scrollProxy: ScrollViewProxy?
    
    // Lista ordenada de todos los IDs para navegación secuencial
    private var allIds: [String] {
        var ids = ["uncategorized"]
        ids.append(contentsOf: PredefinedCategory.allCases.map { $0.rawValue })
        ids.append(contentsOf: promptService.folders
            .filter { !PredefinedCategory.allCases.map { $0.displayName }.contains($0.name) }
            .map { $0.id.uuidString })
        return ids
    }
    
    // Determinar el ID actualmente "activo" para las flechas
    private var currentActiveId: String {
        if let selected = selectedCategory {
            if let pre = PredefinedCategory.allCases.first(where: { $0.displayName == selected }) {
                return pre.rawValue
            }
            if let custom = promptService.folders.first(where: { $0.name == selected }) {
                return custom.id.uuidString
            }
        }
        return "uncategorized"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showLabel {
                headerLabel
            }
            
            scrollViewContent
        }
    }
    
    private var headerLabel: some View {
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
    }
    
    private var scrollViewContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Opción: Sin categoría / General
                    pillView(
                        title: "uncategorized".localized(for: preferences.language),
                        icon: "tag.slash.fill",
                        color: .gray,
                        isSelected: selectedCategory == nil,
                        id: "uncategorized"
                    ) {
                        selectCategory(nil, id: "uncategorized")
                    }
                    
                    // Categorías Predefinidas
                    ForEach(PredefinedCategory.allCases, id: \.self) { cat in
                        pillView(
                            title: cat.displayName,
                            icon: cat.icon,
                            color: cat.color,
                            isSelected: selectedCategory == cat.displayName,
                            id: cat.rawValue
                        ) {
                            selectCategory(cat.displayName, id: cat.rawValue)
                        }
                    }
                    
                    // Carpetas Personalizadas del Usuario
                    ForEach(promptService.folders.filter { !PredefinedCategory.allCases.map { $0.displayName }.contains($0.name) }, id: \.id) { folder in
                        pillView(
                            title: folder.name,
                            icon: folder.icon ?? "folder.fill",
                            color: Color(hex: folder.displayColor),
                            isSelected: selectedCategory == folder.name,
                            id: folder.id.uuidString
                        ) {
                            selectCategory(folder.name, id: folder.id.uuidString)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .leading, endPoint: .trailing)
                        .frame(width: 25)
                    Rectangle()
                    LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing)
                        .frame(width: 25)
                }
            )
            .onAppear {
                scrollProxy = proxy
                // Centrar el seleccionado al aparecer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollTo(currentActiveId)
                }
            }
        }
    }
    
    private func selectCategory(_ name: String?, id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedCategory = name
            scrollTo(id)
        }
        HapticService.shared.playLight()
    }
    
    private func scrollTo(_ id: String) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            scrollProxy?.scrollTo(id, anchor: .center)
        }
    }
    
    @ViewBuilder
    private func pillView(title: String, icon: String, color: Color, isSelected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .id(id)
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
