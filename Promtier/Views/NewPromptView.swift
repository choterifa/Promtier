 //
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct NewPromptView: View {
    var prompt: Prompt?
    var onClose: () -> Void
    
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var selectedIcon: String?
    @State private var showcaseImages: [Data] = []
    @State private var isSaving = false
    @State private var showingZenEditor = false
    @State private var showingIconPicker = false
    @State private var isDragging = false
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium con Acciones
            HStack(alignment: .center) {
                Button(action: onClose) {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(prompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                        .font(.system(size: 15, weight: .bold))
                    Text(prompt != nil ? "Actualiza los detalles" : "Crea una herramienta")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: savePrompt) {
                    Text(prompt != nil ? "Guardar" : "Crear")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                .shadow(color: title.isEmpty || content.isEmpty ? .clear : Color.blue.opacity(0.2), radius: 4, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Contenido Principal - Optimizado para Espacio
            VStack(spacing: 20) {
                // Título y Editor integrados en una gran tarjeta "Content-First"
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 16) {
                        // Selector de Icono
                        Button(action: { showingIconPicker.toggle() }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue).opacity(0.1))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: selectedIcon ?? (selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.icon ?? "doc.text.fill" : "doc.text.fill"))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                            IconPickerView(selectedIcon: $selectedIcon, color: selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue)
                        }
                        .help("Cambiar icono")
                        
                        TextField("Título del prompt...", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18 * preferences.fontSize.scale, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    Divider().padding(.horizontal, 20)
                    
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Escribe aquí el contenido de tu prompt...")
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .font(.system(size: 15 * preferences.fontSize.scale))
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(size: 15 * preferences.fontSize.scale, design: .default))
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Contador de caracteres sutil
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(content.count) caracteres")
                                    .font(.system(size: 10 * preferences.fontSize.scale, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Botón de Modo Zen
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { showingZenEditor = true }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Circle().fill(Color.blue.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                                .help("Modo Zen (Expandido)")
                            }
                            Spacer()
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )
                
                // Organización compacta con ScrollView funcional (Carrusel)
                HStack(spacing: 12) {
                    // Favorito sutil con botón instantáneo
                    Button(action: { isFavorite.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundColor(isFavorite ? .yellow : .secondary)
                            Text("Prioridad")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isFavorite ? Color.yellow.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20)
                    
                    // Categorías horizontales: Carrusel con ScrollViewReader y Botones Físicos
                    ScrollViewReader { proxy in
                        HStack(spacing: 4) {
                            // Botón Scroll Izquierda
                            Button(action: { navigateCategory(forward: false, proxy: proxy) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    CategoryTag(title: "Sin categoría", icon: "folder", color: .gray, isSelected: selectedFolder == nil) {
                                        selectedFolder = nil
                                    }
                                    .id("none")
                                    
                                    ForEach(PredefinedCategory.allCases, id: \.self) { category in
                                        CategoryTag(title: category.displayName, icon: category.icon, color: category.color, isSelected: selectedFolder == category.displayName) {
                                            selectedFolder = category.displayName
                                        }
                                        .id(category.displayName)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 2)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .onChange(of: selectedFolder) { oldValue, newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    proxy.scrollTo(newValue ?? "none", anchor: .center)
                                }
                            }
                            
                            // Botón Scroll Derecha
                            Button(action: { navigateCategory(forward: true, proxy: proxy) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)
                .frame(height: 44)
                
                // Galería de Resultados (Imágenes)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Resultados (Max 3)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if showcaseImages.count < 3 {
                            Button(action: selectImages) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Añadir Imagen")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                if index < showcaseImages.count {
                                    if let nsImage = NSImage(data: showcaseImages[index]) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 60, alignment: .top)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                            )
                                        
                                        Button(action: { showcaseImages.remove(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 5, y: -5)
                                    }
                                } else {
                                    // Placeholder vacío
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primary.opacity(0.03))
                                        .frame(width: 80, height: 60)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary.opacity(0.2))
                                        )
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isDragging ? Color.blue : Color.clear, lineWidth: 2)
                    .background(isDragging ? Color.blue.opacity(0.05) : Color.clear)
            )
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }
        }
        .frame(width: 600, height: 500)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // Decoración sutil
                Circle()
                    .fill(Color.blue.opacity(0.02))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: -250, y: 200)
            }
        )
        .overlay {
            if showingZenEditor {
                ZenEditorView(title: $title, content: $content) {
                    showingZenEditor = false
                }
                .environmentObject(preferences)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if let prompt = prompt {
                title = prompt.title
                content = prompt.content
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
                selectedIcon = prompt.icon
                showcaseImages = prompt.showcaseImages
            }
        }
    }
    
    private func savePrompt() {
        isSaving = true
        
        if let existingPrompt = prompt {
            var updated = existingPrompt
            updated.title = title
            updated.content = content
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.icon = selectedIcon
            updated.showcaseImages = showcaseImages
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
        } else {
            var new = Prompt(title: title, content: content, folder: selectedFolder, icon: selectedIcon, showcaseImages: showcaseImages)
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
        }
        
        onClose()
    }
    
    private func navigateCategory(forward: Bool, proxy: ScrollViewProxy? = nil) {
        let allCategories = [nil] + PredefinedCategory.allCases.map { $0.displayName }
        guard let currentIndex = allCategories.firstIndex(of: selectedFolder) else { return }
        
        let nextIndex: Int 
        if forward {
            nextIndex = (currentIndex + 1) % allCategories.count
        } else {
            nextIndex = (currentIndex - 1 + allCategories.count) % allCategories.count
        }
        
        let newSelection = allCategories[nextIndex]
        selectedFolder = newSelection
        
        if let proxy = proxy {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo(newSelection ?? "none", anchor: .center)
            }
        }
    }
    
    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if showcaseImages.count < 3 {
                    if let data = try? Data(contentsOf: url) {
                        // Opcional: Podríamos comprimir la imagen aquí si Core Data se vuelve lento
                        showcaseImages.append(data)
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url, let data = try? Data(contentsOf: url) {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                showcaseImages.append(data)
                            }
                        }
                    }
                }
                found = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data = data {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                showcaseImages.append(data)
                            }
                        }
                    }
                }
                found = true
            }
        }
        return found
    }
}

struct CategoryTag: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
