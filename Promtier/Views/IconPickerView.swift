//
//  IconPickerView.swift
//  Promtier
//
//  VISTA: Selector de iconos (SFSymbols) para prompts — Categorizado
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    let color: Color
    var categoryName: String? = nil
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isCategorizing = false
    @State private var isHoveringMagic = false
    @State private var searchText = ""
    
    // MARK: - Categorías de Iconos
    
    typealias IconCategory = Theme.Icons.IconCategory
    static var allIconNames: [String] { Theme.Icons.allIconNames }
    
    var filteredCategories: [IconCategory] {
        if searchText.isEmpty {
            return Theme.Icons.categories
        }
        
        let lowerSearch = searchText.lowercased()
        
        // Diccionario ligero para relacionar búsquedas comunes en español con los SFSymbols
        let spanishKeywords = Theme.Icons.spanishKeywords
        
        // Extraemos todas las equivalencias en inglés si el usuario busca una palabra en español
        let mappedKeywords = spanishKeywords.filter { $0.key.contains(lowerSearch) }.flatMap { $0.value }
        
        return Theme.Icons.categories.compactMap { category in
            let filteredIcons = category.icons.filter { icon in
                // Comprueba si el nombre original del icono coincide o si coincide con alguna traducción
                icon.localizedCaseInsensitiveContains(lowerSearch) || 
                mappedKeywords.contains(where: { icon.localizedCaseInsensitiveContains($0) })
            }
            if filteredIcons.isEmpty { return nil }
            return IconCategory(name: category.name, systemImage: category.systemImage, icons: filteredIcons)
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("choose_icon".localized(for: preferences.language))
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                
                if let name = categoryName, !name.isEmpty, preferences.isPreferredAIServiceConfigured {
                    Button(action: {
                        magicIconSelection(for: name)
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isCategorizing ? .gray : (isHoveringMagic ? color : .blue))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringMagic = $0 }
                    .disabled(isCategorizing)
                    .help("Sugerir un icono mágico con IA")
                    .padding(.trailing, 8)
                }

                Button("done".localized(for: preferences.language)) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(isCategorizing)
            }
            .padding(.horizontal, 4)
            
            // Buscador
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("search".localized(for: preferences.language) + "...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 4)
            
            // Opción por defecto (Carpeta)
            if searchText.isEmpty {
                Button(action: {
                    withAnimation(.spring()) { selectedIcon = nil }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundColor(selectedIcon == nil ? color : .secondary)
                        Text("use_category_icon_help".localized(for: preferences.language))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedIcon == nil ? color : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selectedIcon == nil ? color.opacity(0.12) : Color.primary.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedIcon == nil ? color.opacity(0.3) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            // Categorías con iconos
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if filteredCategories.isEmpty {
                        Text("No se encontraron iconos")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    } else {
                        ForEach(filteredCategories) { category in
                            VStack(alignment: .leading, spacing: 6) {
                            // Título de categoría
                            HStack(spacing: 4) {
                                Image(systemName: category.systemImage)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(category.name.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                            }
                            .padding(.leading, 2)
                            
                            // Grid de iconos
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 6) {
                                ForEach(category.icons, id: \.self) { icon in
                                    Button(action: {
                                        withAnimation(.spring()) { selectedIcon = icon }
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? color.opacity(0.15) : Color.primary.opacity(0.04))
                                                .frame(width: 34, height: 34)
                                            
                                            Image(systemName: icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(selectedIcon == icon ? color : .primary.opacity(0.7))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help(icon)
                                }
                            }
                        }
                    }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .frame(width: 320, height: 460)
    }

    private func magicIconSelection(for name: String) {
        isCategorizing = true
        HapticService.shared.playImpact()
        
        let systemPrompt = AIServiceManager.generateCategoryIconPrompt(categoryName: name)
        
        Task {
            do {
                let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                await MainActor.run {
                    self.isCategorizing = false
                    HapticService.shared.playSuccess()
                    let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    if IconPickerView.allIconNames.contains(result) {
                        withAnimation(.spring()) { self.selectedIcon = result }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCategorizing = false
                    HapticService.shared.playImpact()
                }
            }
        }
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("sparkles"), color: .blue)
        .padding()
}
