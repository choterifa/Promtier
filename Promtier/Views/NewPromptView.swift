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
    @State private var negativePrompt = ""
    @State private var alternativePrompt = ""
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
    
    @State private var showNegativeField: Bool = false
    @State private var showAlternativeField: Bool = false
    
    // Identificador para rastrear cambios y guardar borradores
    @State private var originalPrompt: Prompt? = nil
    @State private var isDraftRestored = false
    
    private var currentCategoryColor: Color {
        if let folderName = selectedFolder {
            if let customFolder = promptService.folders.first(where: { $0.name == folderName }) {
                return Color(hex: customFolder.displayColor)
            }
            return PredefinedCategory.fromString(folderName)?.color ?? .blue
        }
        return .blue
    }
    
    // Propiedad calculada para saber si el prompt está vacío
    private var isContentEmpty: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty && 
        content.trimmingCharacters(in: .whitespaces).isEmpty &&
        negativePrompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        alternativePrompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        promptDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        showcaseImages.isEmpty
    }
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
    }
    
    @ViewBuilder
    private func mainScrollViewContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            if preferences.showAdvancedFields {
                HStack(spacing: 8) {
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showNegativeField.toggle() } }) {
                        Text(showNegativeField ? "- Negative" : "+ Negative")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(showNegativeField ? .white : .red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(showNegativeField ? Color.red : Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showAlternativeField.toggle() } }) {
                        Text(showAlternativeField ? "- Alternative" : "+ Alternative")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(showAlternativeField ? .white : .green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(showAlternativeField ? Color.green : Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, -12) // Reducir un poco el espacio visual hacia el editor
            }
            
            EditorCard(
                title: $title,
                content: $content,
                promptDescription: $promptDescription,
                selectedIcon: $selectedIcon,
                fallbackIconName: selectedFolder.flatMap { PredefinedCategory.fromString($0)?.icon } ?? "doc.text.fill",
                showingIconPicker: $showingIconPicker,
                showingZenEditor: $showingZenEditor,
                showingPremiumFor: $showingPremiumFor,
                insertionRequest: $insertionRequest,
                replaceSnippetRequest: $replaceSnippetRequest,
                showSnippets: $showSnippets,
                snippetSearchQuery: $snippetSearchQuery,
                snippetSelectedIndex: $snippetSelectedIndex,
                triggerSnippetSelection: $triggerSnippetSelection,
                triggerAppleIntelligence: $triggerAppleIntelligence,
                isAIActive: $isAIActive,
                currentCategoryColor: currentCategoryColor
            )
            .frame(height: geometry.size.height * 0.83, alignment: .top)
            
            // Nuevas secciones de prompt avanzado
            if preferences.showAdvancedFields && (showNegativeField || showAlternativeField) {
                VStack(spacing: 20) {
                    if showNegativeField {
                        SecondaryEditorCard(
                            title: "negative_prompt".localized(for: preferences.language),
                            placeholder: "negative_prompt_placeholder".localized(for: preferences.language),
                            text: $negativePrompt,
                            icon: "minus.circle.fill",
                            color: .red
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    if showAlternativeField {
                        SecondaryEditorCard(
                            title: "alternative_prompt".localized(for: preferences.language),
                            placeholder: "alternative_prompt_placeholder".localized(for: preferences.language),
                            text: $alternativePrompt,
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            color: .green
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            
            imageGallery
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var fullScreenImageSheetItem: Binding<IdentifiableData?> {
        Binding(
            get: { showingFullScreenImage.map { IdentifiableData(value: $0) } },
            set: { showingFullScreenImage = $0?.value }
        )
    }

    private var premiumSheetItem: Binding<IdentifiableString?> {
        Binding(
            get: { showingPremiumFor.map { IdentifiableString(value: $0) } },
            set: { showingPremiumFor = $0?.value }
        )
    }

    private struct DraftState: Equatable {
        let title: String
        let content: String
        let negativePrompt: String
        let alternativePrompt: String
        let promptDescription: String
        let selectedFolder: String?
        let isFavorite: Bool
        let selectedIcon: String?
        let showcaseImages: [Data]
        let tags: [String]
        let isContentEmpty: Bool
    }

    private var draftState: DraftState {
        DraftState(
            title: title,
            content: content,
            negativePrompt: negativePrompt,
            alternativePrompt: alternativePrompt,
            promptDescription: promptDescription,
            selectedFolder: selectedFolder,
            isFavorite: isFavorite,
            selectedIcon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            isContentEmpty: isContentEmpty
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    mainScrollViewContent(geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundView)
        .sheet(item: fullScreenImageSheetItem) { item in
            FullScreenImageView(imageData: item.value)
        }
        .overlay { overlays }
        .sheet(item: premiumSheetItem) { item in
            PremiumUpsellView(featureName: item.value)
        }
        .onAppear { setupOnAppear() }
        .onChange(of: draftState) { _, newValue in
            saveCurrentDraft()
            MenuBarManager.shared.isModalActive = !newValue.isContentEmpty
        }
    }
    
    @ViewBuilder
    private var overlays: some View {
        Group {
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
    }

    private func setupOnAppear() {
        if let prompt = prompt {
            self.originalPrompt = prompt
            title = prompt.title
            content = prompt.content
            negativePrompt = prompt.negativePrompt ?? ""
            alternativePrompt = prompt.alternativePrompt ?? ""
            promptDescription = prompt.promptDescription ?? ""
            selectedFolder = prompt.folder
            isFavorite = prompt.isFavorite
            selectedIcon = prompt.icon
            showcaseImages = prompt.showcaseImages
            tags = prompt.tags
            
            if !negativePrompt.isEmpty { showNegativeField = true }
            if !alternativePrompt.isEmpty { showAlternativeField = true }

            // Lazy-load de imágenes (la lista ya no carga blobs para mejorar rendimiento).
            if showcaseImages.isEmpty && prompt.showcaseImageCount > 0 {
                Task(priority: .userInitiated) {
                    if let full = await promptService.fetchPrompt(byId: prompt.id, includeImages: true) {
                        await MainActor.run {
                            self.originalPrompt = full
                            // Evitar pisar cambios del usuario si ya añadió imágenes manualmente.
                            if self.showcaseImages.isEmpty {
                                self.showcaseImages = full.showcaseImages
                            }
                        }
                    }
                }
            }
        } else if let draft = DraftService.shared.loadDraft() {
            // Restaurar borrador si existe y no estamos editando uno específico pasado por parámetro
            let draftPrompt = draft.prompt
            
            // Si el borrador era una edición, intentamos recuperar el original
            if draft.isEditing {
                if let original = promptService.prompts.first(where: { $0.id == draftPrompt.id }) {
                    self.originalPrompt = original
                }
            }
            
            title = draftPrompt.title
            content = draftPrompt.content
            negativePrompt = draftPrompt.negativePrompt ?? ""
            alternativePrompt = draftPrompt.alternativePrompt ?? ""
            promptDescription = draftPrompt.promptDescription ?? ""
            selectedFolder = draftPrompt.folder
            isFavorite = draftPrompt.isFavorite
            selectedIcon = draftPrompt.icon
            showcaseImages = draftPrompt.showcaseImages
            tags = draftPrompt.tags
            isDraftRestored = true
            
            if !negativePrompt.isEmpty { showNegativeField = true }
            if !alternativePrompt.isEmpty { showAlternativeField = true }
            
            // Activar bloqueo de popover si el borrador restaurado no está vacío
            if !isContentEmpty {
                MenuBarManager.shared.isModalActive = true
            }
        } else if let activeCategory = promptService.selectedCategory {
            // Autoseleccionar la categoría activa al crear uno nuevo
            selectedFolder = activeCategory
        }
    }
    
    private func saveCurrentDraft() {
        // No guardar si el contenido es idéntico al original que estamos editando
        if let original = originalPrompt {
            let hasChanges = title != original.title || 
                             content != original.content || 
                             promptDescription != (original.promptDescription ?? "") ||
                             selectedFolder != original.folder ||
                             selectedIcon != original.icon ||
                             showcaseImages != original.showcaseImages ||
                             negativePrompt != (original.negativePrompt ?? "") ||
                             alternativePrompt != (original.alternativePrompt ?? "")
            if !hasChanges { return }
        }
        
        // Crear un objeto prompt temporal para el borrador
        var draftPrompt = Prompt(
            title: title,
            content: content,
            promptDescription: promptDescription.isEmpty ? nil : promptDescription,
            folder: selectedFolder,
            icon: selectedIcon,
            showcaseImages: showcaseImages,
            tags: tags,
            negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
            alternativePrompt: alternativePrompt.isEmpty ? nil : alternativePrompt
        )
        
        // Si estamos editando, mantenemos el ID original para poder actualizarlo al restaurar
        if let original = originalPrompt {
            draftPrompt.id = original.id
        }
        
        DraftService.shared.saveDraft(prompt: draftPrompt, isEditing: prompt != nil || originalPrompt != nil)
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack(alignment: .center) {
            Button(action: {
                DraftService.shared.clearDraft()
                MenuBarManager.shared.isModalActive = false
                onClose()
            }) {
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
                        ImageSlotView(
                            imageData: showcaseImages[index],
                            onRemove: { showcaseImages.remove(at: index) },
                            onPreview: { showingFullScreenImage = showcaseImages[index] },
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                            onDragStart: { self.draggedImageIndex = index }
                        )
                    }
                    
                    // Placeholders para completar hasta 3
                    ForEach(showcaseImages.count..<3, id: \.self) { index in
                        PlaceholderSlotView(
                            onSelect: selectImages,
                            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) }
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12) // Añadido horizontal para evitar cortes al escalar
                .contentShape(Rectangle())
                .onTapGesture {
                    selectImages()
                }
            }
            .onPasteCommand(of: [.image]) { providers in
                handleGalleryDrop(providers: providers)
            }
        }
        .padding(.top, 16)
    }
    
    private func handleGalleryDrop(providers: [NSItemProvider], at index: Int? = nil) {
        if let sourceIndex = draggedImageIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let item = showcaseImages.remove(at: sourceIndex)
                let targetIndex = min(index ?? showcaseImages.count, showcaseImages.count)
                showcaseImages.insert(item, at: targetIndex)
                HapticService.shared.playLight()
            }
            draggedImageIndex = nil
            return
        }
        
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url, let data = try? Data(contentsOf: url),
                       let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                if let targetIndex = index, targetIndex < showcaseImages.count {
                                    showcaseImages.insert(optimizedData, at: targetIndex)
                                } else {
                                    showcaseImages.append(optimizedData)
                                }
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            }
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data, let optimizedData = ImageOptimizer.shared.optimize(imageData: data) {
                        DispatchQueue.main.async {
                            if showcaseImages.count < 3 {
                                if let targetIndex = index, targetIndex < showcaseImages.count {
                                    showcaseImages.insert(optimizedData, at: targetIndex)
                                } else {
                                    showcaseImages.append(optimizedData)
                                }
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
        
        // Limpiar borrador al guardar con éxito
        DraftService.shared.clearDraft()
        MenuBarManager.shared.isModalActive = false

        let newNegativePrompt: String? = negativePrompt.isEmpty ? nil : negativePrompt
        let newAlternativePrompt: String? = alternativePrompt.isEmpty ? nil : alternativePrompt
        
        // Usar originalPrompt si existe (restaurado de borrador o asignado en onAppear)
        if let existingPrompt = originalPrompt ?? prompt {
            // Verificar si hay cambios de cualquier tipo para evitar guardados redundantes
            let basicChanges = existingPrompt.title != title ||
                             existingPrompt.content != content ||
                             existingPrompt.promptDescription != (promptDescription.isEmpty ? nil : promptDescription) ||
                             existingPrompt.folder != selectedFolder ||
                             existingPrompt.isFavorite != isFavorite ||
                             existingPrompt.icon != selectedIcon ||
                             existingPrompt.showcaseImages != showcaseImages ||
                             existingPrompt.negativePrompt != newNegativePrompt ||
                             existingPrompt.alternativePrompt != newAlternativePrompt
            
            if !basicChanges {
                onClose()
                return
            }

            var updated = existingPrompt
            
            // ✅ Solo crear snapshot si cambió el Título o el Contenido (Premium)
            if preferences.isPremiumActive {
                let coreChanges = existingPrompt.title != title || 
                                 existingPrompt.content != content ||
                                 existingPrompt.negativePrompt != newNegativePrompt ||
                                 existingPrompt.alternativePrompt != newAlternativePrompt
                
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
            updated.negativePrompt = newNegativePrompt
            updated.alternativePrompt = newAlternativePrompt
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
        } else {
            var new = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? nil : promptDescription,
                folder: selectedFolder,
                icon: selectedIcon,
                showcaseImages: showcaseImages,
                tags: tags,
                negativePrompt: newNegativePrompt,
                alternativePrompt: newAlternativePrompt
            )
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
}

struct EditorCard: View {
    @Binding var title: String
    @Binding var content: String
    @Binding var promptDescription: String
    @Binding var selectedIcon: String?
    let fallbackIconName: String
    @Binding var showingIconPicker: Bool
    @Binding var showingZenEditor: Bool
    @Binding var showingPremiumFor: String?
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    @Binding var triggerAppleIntelligence: Bool
    @Binding var isAIActive: Bool
    
    let currentCategoryColor: Color
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Título e Icono (Header del Documento)
            HStack(alignment: .top, spacing: 16) {
                Button(action: { showingIconPicker.toggle() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentCategoryColor.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: selectedIcon ?? fallbackIconName)
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
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2), lineWidth: 1))

                    Button(action: { showingZenEditor = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 24)
            
            // Área de Texto con IA Flotante
            VStack(alignment: .leading, spacing: 6) {
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
                                    .background(Circle().fill(Color(NSColor.textBackgroundColor)).shadow(color: Color.black.opacity(0.1), radius: 3, y: 1))
                                    .overlay(Circle().stroke(isAIActive ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(10)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.textBackgroundColor).opacity(0.5)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08), lineWidth: 1)))

                Text("\(content.split { $0.isWhitespace }.count) " + "words_count_short".localized(for: preferences.language))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.leading, 8)
            }
        }
    }
}

struct SecondaryEditorCard: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let color: Color
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                HighlightedEditor(
                    text: $text,
                    insertionRequest: .constant(nil),
                    replaceSnippetRequest: .constant(nil),
                    triggerAppleIntelligence: .constant(false),
                    isAIActive: .constant(false),
                    fontSize: 14 * preferences.fontSize.scale,
                    showSnippets: .constant(false),
                    snippetSearchQuery: .constant(""),
                    snippetSelectedIndex: .constant(0),
                    triggerSnippetSelection: .constant(false),
                    isPremium: preferences.isPremiumActive
                )
                .padding(12)
                .frame(minHeight: 120)
                .background(
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(12)
                                .padding(.top, 4)
                        }
                    }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
            )
            
            HStack {
                Text("\(text.split { $0.isWhitespace }.count) " + "words_count_short".localized(for: preferences.language))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.4))
                    .padding(.leading, 8)
                Spacer()
            }
        }
    }
}

// MARK: - Componentes de Soporte de Galería

struct ImageSlotView: View {
    let imageData: Data
    let onRemove: () -> Void
    let onPreview: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    let onDragStart: () -> Void
    
    @State private var isTargeted = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 120, alignment: .center)
                    .clipped()
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTargeted ? Color.blue : Color.primary.opacity(0.05), lineWidth: isTargeted ? 2 : 1)
                    )
                    .onTapGesture(perform: onPreview)
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.image.identifier)
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    .scaleEffect(isTargeted ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isTargeted)
                
                Button(action: onRemove) {
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
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

struct PlaceholderSlotView: View {
    let onSelect: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    
    @State private var isTargeted = false
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.4))
                
                Text("add_prompt_results".localized(for: preferences.language))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.4))
            }
            .frame(width: 180, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [4]))
                            .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.2))
                    )
            )
            .scaleEffect(isTargeted ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isTargeted)
        }
        .buttonStyle(.plain)
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
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
