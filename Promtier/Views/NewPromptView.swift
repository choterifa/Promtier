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
    @State private var promptDescription = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var selectedIcon: String?
    @State private var showcaseImages: [Data] = []
    @State private var isSaving = false
    @State private var showingZenEditor = false
    @State private var showingIconPicker = false
    @State private var isDragging = false
    @State private var draggedImageIndex: Int? = nil
    @State private var showingFullScreenImage: Data? = nil
    
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var showingTagEditor: Bool = false
    
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        editorCard
                            .frame(height: geometry.size.height * 0.75, alignment: .top)
                        
                        imageGallery
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
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
                promptDescription = prompt.promptDescription ?? ""
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
                selectedIcon = prompt.icon
                showcaseImages = prompt.showcaseImages
                tags = prompt.tags
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
                Text("cancel".localized(for: preferences.language))
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
                Text(prompt != nil ? "edit_prompt".localized(for: preferences.language) : "new_prompt".localized(for: preferences.language))
                    .font(.system(size: 15, weight: .bold))
                Text(prompt != nil ? "update_details".localized(for: preferences.language) : "create_tool".localized(for: preferences.language))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: savePrompt) {
                Text(prompt != nil ? "save".localized(for: preferences.language) : "create".localized(for: preferences.language))
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
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var editorCard: some View {
        VStack(spacing: 0) {
            // Título e Icono (Header del Documento)
            HStack(alignment: .top, spacing: 16) {
                Button(action: { showingIconPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentCategoryColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: selectedIcon ?? (selectedFolder != nil ? PredefinedCategory.fromString(selectedFolder!)?.icon ?? "doc.text.fill" : "doc.text.fill"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(currentCategoryColor)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                    IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22 * preferences.fontSize.scale, weight: .bold))
                    
                    TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13 * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Toolbar de Acciones (Header)
                HStack(spacing: 8) {
                    // Variables y Snippets (Ahora en el Header)
                    HStack(spacing: 0) {
                        Button(action: { 
                            if preferences.isPremiumActive {
                                insertionRequest = "{{variable}}"
                            } else {
                                showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                            }
                        }) {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .help("insert_variable_hint".localized(for: preferences.language))
                        
                        Divider().frame(height: 18).background(Color.blue.opacity(0.2))
                        
                        Button(action: {
                            if preferences.isPremiumActive {
                                showSnippets = true
                                snippetSearchQuery = ""
                            } else {
                                showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                            }
                        }) {
                            Text("/")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .help("insert_snippet_hint".localized(for: preferences.language))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )

                    Button(action: { showingZenEditor = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("zen_editor".localized(for: preferences.language))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 24)
            
            // Área de Texto con IA Flotante
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    HighlightedEditor(
                        text: $content,
                        insertionRequest: $insertionRequest,
                        replaceSnippetRequest: $replaceSnippetRequest,
                        triggerAppleIntelligence: $triggerAppleIntelligence,
                        isAIActive: $isAIActive,
                        fontSize: 16 * preferences.fontSize.scale,
                        showSnippets: $showSnippets,
                        snippetSearchQuery: $snippetSearchQuery,
                        snippetSelectedIndex: $snippetSelectedIndex,
                        triggerSnippetSelection: $triggerSnippetSelection,
                        isPremium: preferences.isPremiumActive
                    )
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Botón Apple Intelligence (Esquina inferior derecha del editor)
                    if preferences.appleIntelligenceEnabled {
                        Button(action: {
                            triggerAppleIntelligence = true
                            HapticService.shared.playLight()
                        }) {
                            Image(systemName: "apple.intelligence")
                                .font(.system(size: 13, weight: .bold))
                                .symbolRenderingMode(isAIActive ? .monochrome : .multicolor)
                                .foregroundColor(isAIActive ? .blue : .primary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.textBackgroundColor))
                                        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isAIActive ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(10)
                        .help("apple_intelligence".localized(for: preferences.language))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    private var imageGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("prompt_results".localized(for: preferences.language))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .textCase(.uppercase)
                
                if showcaseImages.count < 3 {
                    Button(action: selectImages) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help("add_image".localized(for: preferences.language))
                }
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Imágenes actuales
                    ForEach(0..<showcaseImages.count, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            if let nsImage = NSImage(data: showcaseImages[index]) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 180, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        showingFullScreenImage = showcaseImages[index]
                                    }
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                
                                Button(action: { showcaseImages.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    
                    // Placeholders para completar hasta 3
                    ForEach(showcaseImages.count..<3, id: \.self) { _ in
                        Button(action: selectImages) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 20))
                                Text("add_prompt_results".localized(for: preferences.language))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.secondary.opacity(0.4))
                            .frame(width: 180, height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(.secondary.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 20)
            }
        }
        .padding(.top, 16)
    }
    
    private func handleGalleryDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, let data = try? Data(contentsOf: url) {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                showcaseImages.append(data)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                showcaseImages.append(data)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                        }
                    }
                }
            }
        }
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
                             existingPrompt.promptDescription != (promptDescription.isEmpty ? nil : promptDescription) ||
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
            updated.promptDescription = promptDescription.isEmpty ? nil : promptDescription
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.icon = selectedIcon
            updated.showcaseImages = showcaseImages
            updated.tags = tags
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
        } else {
            var new = Prompt(title: title, content: content, promptDescription: promptDescription.isEmpty ? nil : promptDescription, folder: selectedFolder, icon: selectedIcon, showcaseImages: showcaseImages, tags: tags)
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
                    featureName: "quick_snippets".localized(for: preferences.language),
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
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("category".localized(for: preferences.language), systemImage: "folder.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "uncategorized".localized(for: preferences.language), icon: "folder", color: .secondary, isSelected: selectedFolder == nil) {
                        withAnimation(.spring()) {
                            selectedFolder = nil
                        }
                    }
                    
                    ForEach(promptService.folders) { folder in
                        CategoryChip(
                            title: folder.name,
                            icon: folder.icon ?? "folder.fill",
                            color: Color(hex: folder.displayColor),
                            isSelected: selectedFolder == folder.name
                        ) {
                            withAnimation(.spring()) {
                                selectedFolder = folder.name
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
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
                    .font(.system(size: 11, weight: .semibold))
                Text(LocalizedStringKey(title))
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color : color.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : color.opacity(0.15), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : color.opacity(0.9))
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

struct FlowLayout: View {
    var spacing: CGFloat
    var children: [AnyView]

    init<Data: Collection, ID: Hashable, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.children = data.map { AnyView(content($0)) }
    }
    
    // Simplificado para el ForEach usual
    init(spacing: CGFloat, @ViewBuilder content: () -> AnyView) {
        self.spacing = spacing
        self.children = [content()]
    }
    
    init<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        // Esto es un hack para prototipar rápido, idealmente usaríamos Layout protocol en iOS 16+
        self.children = [AnyView(content())]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            let height = CGFloat.zero
            
            Color.clear
                .frame(height: height) // placeholder
            
            // Nota: En macOS/SwiftUI esto es mejor con un View que calcule geometrías.
            // Para mantenerlo simple y compatible:
            HStack(spacing: spacing) {
                // Aquí usamos un HStack simple para este caso, pero el nombre FlowLayout se queda para expansión
                // En este caso como son pocas etiquetas, un HStack con Wrap (si existiera nativo) sería ideal.
                ForEach(0..<children.count, id: \.self) { i in
                    children[i]
                }
            }
        }
    }
}
