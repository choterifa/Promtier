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
    @State private var showingFullScreenImage: Data? = nil
    
    @State private var insertionRequest: String? = nil
    @State private var replaceSnippetRequest: String? = nil
    @State private var showSnippets: Bool = false
    @State private var snippetSearchQuery: String = ""
    @State private var snippetSelectedIndex: Int = 0
    @State private var triggerSnippetSelection: Bool = false
    
    @State private var triggerAppleIntelligence: Bool = false
    @State private var isAIActive: Bool = false
    @State private var showParticles: Bool = false
    @State private var showingVersionHistory: Bool = false
    @State private var showingPremiumFor: String? = nil // Determina qué feature premium mostrar en el upsell
    
    private var currentCategoryColor: Color {
        if let folderName = selectedFolder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .blue
        }
        return .blue
    }
    
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
                
                categoryPicker
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        editorCard
                            .frame(height: geometry.size.height * 0.65, alignment: .top)
                        
                        imageGallery
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundView)
        .sheet(item: Binding(
            get: { showingFullScreenImage.map { IdentifiableData(value: $0) } },
            set: { showingFullScreenImage = $0?.value }
        )) { item in
            FullScreenImageView(imageData: item.value)
        }
        .overlay {
            if showingZenEditor {
                ZenEditorView(
                    title: $title,
                    content: $content,
                    onDone: { showingZenEditor = false },
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    triggerAppleIntelligence: $triggerAppleIntelligence,
                    isAIActive: $isAIActive,
                    showingPremiumFor: $showingPremiumFor
                )
                .environmentObject(preferences)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showSnippets {
                snippetOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                    .zIndex(200)
            }
            if showParticles {
                ParticleSystemView(accentColor: currentCategoryColor)
                    .allowsHitTesting(false)
                    .zIndex(300)
            }
        }
        .sheet(item: Binding(
            get: { showingPremiumFor.map { IdentifiableString(value: $0) } },
            set: { showingPremiumFor = $0?.value }
        )) { item in
            PremiumUpsellView(featureName: item.value)
        }
        .onAppear {
            if let prompt = prompt {
                title = prompt.title
                content = prompt.content
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
                selectedIcon = prompt.icon
                showcaseImages = prompt.showcaseImages
            } else if let activeCategory = promptService.selectedCategory {
                // Autoseleccionar la categoría activa al crear uno nuevo
                selectedFolder = activeCategory
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
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 40 {
                            title = String(newValue.prefix(40))
                        }
                    }
                
                HStack(spacing: 4) {
                    // Botón Variables (Premium)
                    Button(action: { 
                        if preferences.isPremiumActive {
                            insertionRequest = "{{variable}}"
                        } else {
                            showingPremiumFor = "Variables Dinámicas"
                        }
                    }) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help("Insertar Variable")
                    
                    // Botón Snippets '/' (Premium)
                    Button(action: {
                        if preferences.isPremiumActive {
                            showSnippets = true
                            snippetSearchQuery = ""
                        } else {
                            showingPremiumFor = "Snippets Reutilizables"
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 28, height: 28)
                            Text("/")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help("Insertar Snippet")

                    // Botón historial (solo en edición, solo Premium)
                    if prompt != nil && preferences.isPremiumActive && !(prompt?.versionHistory.isEmpty ?? true) {
                        Button(action: { showingVersionHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Circle().fill(Color.blue.opacity(0.1)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .help("Historial de versiones")
                        .sheet(isPresented: $showingVersionHistory) {
                            if let existingPrompt = prompt {
                                VersionHistoryView(
                                    snapshots: existingPrompt.versionHistory,
                                    currentContent: content,
                                    onRestore: { snapshot in
                                        content = snapshot.content
                                        title   = snapshot.title
                                        showingVersionHistory = false
                                    }
                                )
                                .environmentObject(preferences)
                            }
                        }
                    }



                    // Botón Apple Intelligence (Único y rápido)
                    if preferences.appleIntelligenceEnabled {
                        Button(action: {
                            triggerAppleIntelligence = true
                            let haptic = NSHapticFeedbackManager.defaultPerformer
                            haptic.perform(.generic, performanceTime: .now)
                        }) {
                            Image(systemName: "apple.intelligence")
                                .font(.system(size: 14, weight: .bold))
                                .symbolRenderingMode(isAIActive ? .monochrome : .multicolor)
                                .foregroundColor(isAIActive ? .blue : .primary)
                                .padding(8)
                                .background(Circle().fill(isAIActive ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .help("Apple Intelligence (Editar con IA)")
                    }

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
                    replaceSnippetRequest: $replaceSnippetRequest,
                    triggerAppleIntelligence: $triggerAppleIntelligence,
                    isAIActive: $isAIActive,
                    fontSize: 15 * preferences.fontSize.scale,
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    isPremium: preferences.isPremiumActive
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
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Añadir Imagen")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
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
                                    .frame(width: 140, height: 100, alignment: .top)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        showingFullScreenImage = showcaseImages[index]
                                    }
                                
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
                    Text("Añadir ejemplos del prompt")
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
            // Verificar si hay cambios de cualquier tipo para evitar guardados redundantes
            let basicChanges = existingPrompt.title != title ||
                             existingPrompt.content != content ||
                             existingPrompt.folder != selectedFolder ||
                             existingPrompt.isFavorite != isFavorite ||
                             existingPrompt.icon != selectedIcon ||
                             existingPrompt.showcaseImages != showcaseImages
            
            if !basicChanges {
                onClose()
                return
            }

            var updated = existingPrompt
            
            // ✅ Solo crear snapshot si cambió el Título o el Contenido (Premium)
            if preferences.isPremiumActive {
                let coreChanges = existingPrompt.title != title || existingPrompt.content != content
                
                if coreChanges {
                    let snapshot = PromptSnapshot(
                        title:     existingPrompt.title,
                        content:   existingPrompt.content,
                        timestamp: Date()
                    )
                    var history = existingPrompt.versionHistory
                    history.insert(snapshot, at: 0)
                    if history.count > 20 { history = Array(history.prefix(20)) }
                    updated.versionHistory = history
                }
            }
            
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
        
        if preferences.isPremiumActive && preferences.visualEffectsEnabled {
            showParticles = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onClose()
            }
        } else {
            onClose()
        }
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
    
    private var snippetOverlay: some View {
        VStack {
            Spacer()
            if !preferences.isPremiumActive {
                PremiumUpsellView(
                    featureName: "Snippets Rápidos",
                    onCancel: {
                        withAnimation { showSnippets = false }
                    }
                )
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                .padding(.bottom, 24)
            } else {
                SnippetsPopupList(
                    query: snippetSearchQuery,
                    selectedIndex: $snippetSelectedIndex,
                    triggerSelection: $triggerSnippetSelection,
                    onSelect: { snippet in
                        replaceSnippetRequest = snippet.content
                    },
                    onDismiss: {
                        withAnimation { showSnippets = false }
                    }
                )
                .padding(.bottom, 24)
            }
        }
    }
    
    private var categoryPicker: some View {
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
                    .padding(.leading, 24)
                    
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
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: { navigateCategory(forward: true, proxy: proxy) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                }
            }
        }
        .background(Color.primary.opacity(0.02))
        .overlay(Divider(), alignment: .bottom)
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

// Helper para convertir String a Identifiable para .sheet
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct IdentifiableData: Identifiable {
    let id = UUID()
    let value: Data
}
