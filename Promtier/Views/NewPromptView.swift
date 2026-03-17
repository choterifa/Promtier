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
    
    @State private var insertionRequest: String? = nil
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                
                Divider()
                    .padding(.horizontal, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        editorCard
                            .frame(height: geometry.size.height * 0.7, alignment: .top)
                        
                        imageGallery
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundView)
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
    
    // MARK: - Subviews
    
    private var header: some View {
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
    }
    
    private var editorCard: some View {
        VStack(spacing: 0) {
            // Título, Icono y Favorito
            HStack(alignment: .center, spacing: 12) {
                Button(action: { showingIconPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue).opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: selectedIcon ?? (selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.icon ?? "doc.text.fill" : "doc.text.fill"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                    IconPickerView(selectedIcon: $selectedIcon, color: selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.color ?? .blue : .blue)
                }
                
                TextField("Título del prompt...", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18 * preferences.fontSize.scale, weight: .bold))
                
                HStack(spacing: 4) {
                    Button(action: { 
                        insertionRequest = "{{variable}}"
                        // Micro-interacción: trigger haptic or animation value could be added here
                    }) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help("Insertar Variable")

                    Button(action: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isFavorite.toggle()
                        }
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isFavorite ? .yellow : .secondary.opacity(0.5))
                            .padding(8)
                            .background(Circle().fill(isFavorite ? Color.yellow.opacity(0.1) : Color.clear))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help(isFavorite ? "Quitar de favoritos" : "Marcar como favorito")

                    Button(action: { showingZenEditor = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("Editor Zen")
                }
            }
            .frame(minHeight: 44) // Asegura que el título sea visible
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            Divider().padding(.horizontal, 20)
            
            // Chips de Categorías con Carrusel
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    HStack(spacing: 8) {
                        Button(action: { navigateCategory(forward: false, proxy: proxy) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryChip(title: "Sin categoría", icon: "folder", color: .secondary, isSelected: selectedFolder == nil) {
                                    selectedFolder = nil
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        proxy.scrollTo("none", anchor: .center)
                                    }
                                }
                                .id("none")
                                
                                ForEach(promptService.folders) { folder in
                                    CategoryChip(
                                        title: folder.name,
                                        icon: folder.icon ?? "folder.fill",
                                        color: Color(hex: folder.displayColor),
                                        isSelected: selectedFolder == folder.name
                                    ) {
                                        selectedFolder = folder.name
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            proxy.scrollTo(folder.name, anchor: .center)
                                        }
                                    }
                                    .id(folder.name)
                                }
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedFolder)
                        
                        Button(action: { navigateCategory(forward: true, proxy: proxy) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }
                }
            }
            .padding(.vertical, 10)
            
            Divider().padding(.horizontal, 20)
            
            // Área de Texto
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Escribe aquí el contenido de tu prompt...")
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .font(.system(size: 15 * preferences.fontSize.scale))
                }
                
                HighlightedEditor(
                    text: $content,
                    insertionRequest: $insertionRequest,
                    fontSize: 15 * preferences.fontSize.scale
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Botón Zen removido de aquí (movido al título)
            }
            
            HStack {
                Spacer()
                Label("\(content.count) caracteres", systemImage: "character.cursor.ibeam")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
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
    }
    
    private var imageGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Imágenes de Referencia", systemImage: "photo.on.rectangle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showcaseImages.count < 3 {
                    Button(action: selectImages) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        if index < showcaseImages.count {
                            if let nsImage = NSImage(data: showcaseImages[index]) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 60)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                
                                Button(action: { showcaseImages.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                                .frame(width: 80, height: 60)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary.opacity(0.1))
                                )
                        }
                    }
                }
                
                if showcaseImages.isEmpty {
                    Text("Añade ejemplos visuales arrastrando aquí")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
    
    private var backgroundView: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            Circle()
                .fill(Color.blue.opacity(0.02))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: -250, y: 200)
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
        let allCategories = [nil] + promptService.folders.map { $0.name }
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
                    if let data = try? Data(contentsOf: url),
                       let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        showcaseImages.append(optimizedData)
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
                        if let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                            DispatchQueue.main.async {
                                if showcaseImages.count < 3 {
                                    showcaseImages.append(optimizedData)
                                }
                            }
                        }
                    }
                }
                found = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data = data, let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                showcaseImages.append(optimizedData)
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

// MARK: - Components

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.08))
            )
            .foregroundColor(isSelected ? .white : color.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
