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
    @Binding var isFavorite: Bool
    var showLabel: Bool = true
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var scrollProxy: ScrollViewProxy?
    
    // Estado para nueva categoría
    @State private var showingNewCategoryPopover = false
    @State private var newCategoryName = ""
    @State private var selectedNewColor: Color = .blue
    @State private var isPlusHovered = false
    
    // Estado para eliminación de categoría
    @State private var folderToDelete: Folder? = nil
    @State private var showingDeleteAlert = false
    
    private let presetColors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .mint, .cyan, .gray]
    
    // Lista ordenada de todos los IDs para navegación secuencial
    private var allIds: [String] {
        var ids = ["uncategorized"]
        
        // Primero las carpetas personalizadas (nuevas primero)
        let customFolderIds = promptService.folders
            .filter { !PredefinedCategory.allCases.map { $0.displayName }.contains($0.name) }
            .map { $0.id.uuidString }
        ids.append(contentsOf: customFolderIds)
        
        // Luego las predefinidas
        ids.append(contentsOf: PredefinedCategory.allCases.map { $0.rawValue })
        
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
        .alert("delete_category_title".localized(for: preferences.language), isPresented: $showingDeleteAlert, presenting: folderToDelete) { folder in
            Button("delete".localized(for: preferences.language), role: .destructive) {
                deleteCategory(folder)
            }
            Button("cancel".localized(for: preferences.language), role: .cancel) { }
        } message: { folder in
            let count = promptService.prompts.filter { $0.folder == folder.name }.count
            if count > 0 {
                Text(String(format: "delete_category_with_items_msg".localized(for: preferences.language), count))
            } else {
                Text("delete_category_generic_msg".localized(for: preferences.language))
            }
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
                HStack(spacing: 14) {
                    // Botón para añadir nueva categoría (Primero y SEPARADO)
                    plusButton
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, 4)

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
                    
                                                            // Carpetas Personalizadas del Usuario (Las más nuevas primero, justo después de sin categoría)
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
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        folderToDelete = folder
                                                        showingDeleteAlert = true
                                                    } label: {
                                                        Label("delete".localized(for: preferences.language), systemImage: "trash")
                                                    }
                                                }
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20) // Aumentado para evitar corte de sombras
            }
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .leading, endPoint: .trailing)
                        .frame(width: 40)
                    Rectangle()
                    LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing)
                        .frame(width: 40)
                }
            )
            .onAppear {
                scrollProxy = proxy
                // Centrar el seleccionado al aparecer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollTo(currentActiveId)
                }
            }
            .onChange(of: selectedCategory) { 
                // Desplazar automáticamente cuando cambie la categoría (p. ej. por la IA)
                scrollTo(currentActiveId)
            }
        }
    }
    
    private func selectCategory(_ name: String?, id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedCategory = name
            scrollTo(id)
        }
        HapticService.shared.playLight()
    }
    
    private func scrollTo(_ id: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            scrollProxy?.scrollTo(id, anchor: .center)
        }
    }
    
    @ViewBuilder
    private func pillView(title: String, icon: String, color: Color, isSelected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .id(id)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
            .background(
                ZStack {
                    if isSelected {
                        // Resplandor de Selección (Glow Pro)
                        let pillColor = preferences.isHaloEffectEnabled ? color : (color == .gray ? .gray.opacity(0.6) : color.opacity(0.8))
                        RoundedRectangle(cornerRadius: 12)
                            .fill(pillColor)
                            .shadow(color: preferences.isHaloEffectEnabled ? pillColor.opacity(0.45) : .clear, radius: 10, x: 0, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var plusButton: some View {
        Button(action: { showingNewCategoryPopover = true }) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(isPlusHovered ? 0.1 : 0.06))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isPlusHovered ? .primary : .secondary)
            }
            .scaleEffect(1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isPlusHovered = hovering
        }
        .popover(isPresented: $showingNewCategoryPopover, arrowEdge: .top) {
            newCategoryForm
        }
    }
    
    private var newCategoryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("new_category".localized(for: preferences.language))
                .font(.system(size: 14, weight: .bold))
            
            TextField("name_placeholder".localized(for: preferences.language), text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            // Selector de Color simplificado
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 24))], spacing: 10) {
                ForEach(presetColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selectedNewColor == color ? 2 : 0)
                                .shadow(radius: 1)
                        )
                        .onTapGesture {
                            selectedNewColor = color
                        }
                }
                
                // Color Picker Personalizado (Punto Multicolor Refinado)
                ZStack {
                    AngularGradient(
                        gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red]),
                        center: .center
                    )
                    .clipShape(Circle())
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedNewColor != .gray ? 2 : 1)
                            .shadow(radius: 1)
                    )
                    
                    ColorPicker("", selection: $selectedNewColor)
                        .labelsHidden()
                        .opacity(0.011) // Invísimble pero interactivo
                        .frame(width: 24, height: 24)
                }
            }
            
            Button(action: createCategory) {
                Text("create".localized(for: preferences.language))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(newCategoryName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(newCategoryName.isEmpty)
        }
        .padding(16)
    }
    
    private func createCategory() {
        let hex = "#" + NSColor(selectedNewColor).hexString
        let newFolder = Folder(name: newCategoryName, color: hex, icon: "folder.fill")
        
        if promptService.createFolder(newFolder) {
            selectedCategory = newCategoryName
            newCategoryName = ""
            showingNewCategoryPopover = false
            HapticService.shared.playSuccess()
            
            // Scroll a la nueva categoría
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let newId = promptService.folders.first(where: { $0.name == selectedCategory })?.id.uuidString {
                    scrollTo(newId)
                }
            }
        }
    }
    
    private func deleteCategory(_ folder: Folder) {
        let nameToDelete = folder.name
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if promptService.deleteFolder(folder) {
                // Si la categoría eliminada era la seleccionada, volver a General
                if selectedCategory == nameToDelete {
                    selectedCategory = nil
                    scrollTo("uncategorized")
                }
                HapticService.shared.playSuccess()
            }
        }
    }
}
