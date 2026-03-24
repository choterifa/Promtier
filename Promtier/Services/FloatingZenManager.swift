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
    @Published var lastSaveSuccess: Bool = false
    
    private var autoSaveTimer: Timer?
    private var originalPromptId: UUID?
    private var isEditingExisting: Bool = false
    
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
        
        if panel == nil { createPanel() }
        
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    /// Guarda directamente como nuevo prompt en PromptService
    func saveAsNewPrompt() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSaving = true
        
        let newPrompt = Prompt(
            title: title,
            content: content,
            promptDescription: promptDescription.isEmpty ? nil : promptDescription,
            folder: selectedFolder,
            showcaseImages: Array(showcaseImages.prefix(3))
        )
        
        _ = PromptService.shared.createPrompt(newPrompt)
        
        HapticService.shared.playSuccess()
        if PreferencesManager.shared.soundEnabled {
            SoundService.shared.playMagicSound()
        }
        
        lastSaveSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.resetAndHide()
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
