//
//  FloatingZenManager.swift
//  Promtier
//
//  SERVICIO: Gestor del editor Zen Flotante / Fast Add Mode
//

import SwiftUI
import AppKit
import Combine

class FloatingZenManager: NSObject, ObservableObject {
    static let shared = FloatingZenManager()
    
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var title: String = ""
    @Published var promptDescription: String = ""
    @Published var content: String = ""
    @Published var showcaseImages: [Data] = []
    @Published var selectedFolder: String? = nil
    @Published var isVisible: Bool = false
    @Published var isSaving: Bool = false
    @Published var isClassifying: Bool = false
    @Published var lastSaveSuccess: Bool = false
    
    private var autoSaveTimer: Timer?
    private var originalPromptId: UUID?
    private var isEditingExisting: Bool = false
    
    // Initial state to detect changes
    private var initialTitle: String = ""
    private var initialDescription: String = ""
    private var initialContent: String = ""
    private var initialImages: [Data] = []
    
    var hasUnsavedChanges: Bool {
        title != initialTitle || 
        promptDescription != initialDescription || 
        content != initialContent || 
        showcaseImages != initialImages
    }
    
    private override init() {
        super.init()
        
        $content
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleAutoSave() }
            .store(in: &cancellables)
            
        $title
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleAutoSave() }
            .store(in: &cancellables)
            
        $promptDescription
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleAutoSave() }
            .store(in: &cancellables)
    }
    
    func show(title: String, promptDescription: String, content: String, promptId: UUID?, isEditing: Bool) {
        self.title = title
        self.promptDescription = promptDescription
        self.content = content
        self.originalPromptId = promptId
        self.isEditingExisting = isEditing
        self.showcaseImages = []
        self.lastSaveSuccess = false
        
        // Save initial state to detect changes later
        self.initialTitle = title
        self.initialDescription = promptDescription
        self.initialContent = content
        self.initialImages = []
        
        if panel == nil { createPanel() }
        
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    /// Guarda directamente como nuevo prompt en PromptService
    func saveAsNewPrompt() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        
        Task {
            // Si hay API, intentar clasificar automáticamente antes de guardar
            let prefs = PreferencesManager.shared
            let hasOpenAI = !prefs.openAIApiKey.isEmpty && prefs.openAIEnabled
            let hasGemini = !prefs.geminiAPIKey.isEmpty && prefs.geminiEnabled
            
            if hasOpenAI || hasGemini {
                await MainActor.run { self.isClassifying = true }
                let folders = PromptService.shared.folders.map { $0.name }
                if let autoCategory = await classifyCurrentPrompt(title: title, content: content, folders: folders) {
                    await MainActor.run { self.selectedFolder = autoCategory }
                }
                await MainActor.run { self.isClassifying = false }
            }
            
            await MainActor.run {
                let newPrompt = Prompt(
                    title: self.title,
                    content: self.content,
                    promptDescription: self.promptDescription.isEmpty ? nil : self.promptDescription,
                    folder: self.selectedFolder,
                    showcaseImages: Array(self.showcaseImages.prefix(3))
                )
                
                _ = PromptService.shared.createPrompt(newPrompt)
                
                HapticService.shared.playSuccess()
                if PreferencesManager.shared.soundEnabled {
                    SoundService.shared.playMagicSound()
                }
                
                self.lastSaveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    self?.resetAndHide()
                }
            }
        }
    }
    
    private func classifyCurrentPrompt(title: String, content: String, folders: [String]) async -> String? {
        guard !folders.isEmpty else { return nil }
        
        let prefs = PreferencesManager.shared
        let systemPrompt = """
        Your task is to classify an AI prompt into one of the following existing categories.
        Respond ONLY with the category name, exactly as it appears in the list.
        If no category matches well, respond with "Uncategorized".
        
        Categories:
        \(folders.joined(separator: "\n"))
        
        Prompt to classify:
        Title: \(title)
        Content: \(content)
        """
        
        let model = prefs.preferredAIService == .openai ? prefs.openAIDefaultModel : prefs.geminiDefaultModel
        let apiKey = prefs.preferredAIService == .openai ? prefs.openAIApiKey : prefs.geminiAPIKey
        
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            let publisher: AnyPublisher<String, Error>
            
            if prefs.preferredAIService == .openai {
                publisher = OpenAIService.shared.generate(prompt: systemPrompt, model: model, apiKey: apiKey)
            } else {
                publisher = GeminiService.shared.generate(prompt: systemPrompt, model: model)
            }
            
            var fullResponse = ""
            cancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure = completion {
                        continuation.resume(returning: nil)
                    } else {
                        let final = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        if folders.contains(final) {
                            continuation.resume(returning: final)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                    cancellable?.cancel()
                }, receiveValue: { value in
                    fullResponse += value
                })
        }
    }
    
    func resetAndHide() {
        panel?.orderOut(nil)
        isVisible = false
        isSaving = false
        lastSaveSuccess = false
        title = ""
        promptDescription = ""
        content = ""
        showcaseImages = []
        selectedFolder = nil
        originalPromptId = nil
        isEditingExisting = false
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        forceAutoSave()
    }
    
    private func createPanel() {
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        newPanel.hasShadow = true
        newPanel.delegate = self
        newPanel.center()
        
        let view = FloatingZenEditorView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
            .environmentObject(PromptService.shared)
        
        newPanel.contentView = NSHostingView(rootView: view)
        self.panel = newPanel
    }
    
    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.forceAutoSave()
        }
    }
    
    private func forceAutoSave() {
        var currentPrompt: Prompt
        if let existing = DraftService.shared.loadDraft() {
            currentPrompt = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? existing.prompt.promptDescription : promptDescription,
                folder: existing.prompt.folder,
                icon: existing.prompt.icon,
                showcaseImages: showcaseImages.isEmpty ? existing.prompt.showcaseImages : showcaseImages,
                tags: existing.prompt.tags,
                targetAppBundleIDs: existing.prompt.targetAppBundleIDs,
                negativePrompt: existing.prompt.negativePrompt,
                alternativePrompt: existing.prompt.alternativePrompt,
                alternatives: existing.prompt.alternatives,
                customShortcut: existing.prompt.customShortcut
            )
            currentPrompt.id = originalPromptId ?? existing.prompt.id
            currentPrompt.createdAt = existing.prompt.createdAt
            currentPrompt.lastUsedAt = existing.prompt.lastUsedAt
            currentPrompt.useCount = existing.prompt.useCount
            currentPrompt.isFavorite = existing.prompt.isFavorite
            currentPrompt.parentID = existing.prompt.parentID
            currentPrompt.versionHistory = existing.prompt.versionHistory
        } else {
            currentPrompt = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? nil : promptDescription,
                showcaseImages: showcaseImages
            )
            if let originalId = originalPromptId {
                currentPrompt.id = originalId
            }
        }
        
        DraftService.shared.saveDraft(prompt: currentPrompt, isEditing: isEditingExisting)
        NotificationCenter.default.post(name: NSNotification.Name("FloatingZenDraftUpdated"), object: nil)
    }
}

extension FloatingZenManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isVisible = false
        forceAutoSave()
    }
}
