//
//  FloatingZenManager.swift
//  Promtier
//
//  SERVICIO: Gestor del editor Zen Flotante
//

import SwiftUI
import AppKit
import Combine

class FloatingZenManager: NSObject, ObservableObject {
    static let shared = FloatingZenManager()
    
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var isVisible: Bool = false
    
    // We use a timer to debounce autosaving to draft
    private var autoSaveTimer: Timer?
    
    // To know if we are editing an existing prompt
    private var originalPromptId: UUID?
    private var isEditingExisting: Bool = false
    
    private override init() {
        super.init()
        
        $content
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleAutoSave()
            }
            .store(in: &cancellables)
            
        $title
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleAutoSave()
            }
            .store(in: &cancellables)
    }
    
    func show(title: String, content: String, promptId: UUID?, isEditing: Bool) {
        self.title = title
        self.content = content
        self.originalPromptId = promptId
        self.isEditingExisting = isEditing
        
        if panel == nil {
            createPanel()
        }
        
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        forceAutoSave()
    }
    
    private func createPanel() {
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
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
        
        // Center the panel on the screen
        newPanel.center()
        
        let view = FloatingZenEditorView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
        
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
                promptDescription: existing.prompt.promptDescription,
                folder: existing.prompt.folder,
                icon: existing.prompt.icon,
                showcaseImages: existing.prompt.showcaseImages,
                tags: existing.prompt.tags,
                targetAppBundleIDs: existing.prompt.targetAppBundleIDs,
                negativePrompt: existing.prompt.negativePrompt,
                alternativePrompt: existing.prompt.alternativePrompt,
                alternatives: existing.prompt.alternatives,
                customShortcut: existing.prompt.customShortcut
            )
            // Restore hidden properties
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
                content: content
            )
            if let originalId = originalPromptId {
                currentPrompt.id = originalId
            }
        }
        
        DraftService.shared.saveDraft(prompt: currentPrompt, isEditing: isEditingExisting)
        
        // Let NewPromptView know there's a draft update if it's currently open
        NotificationCenter.default.post(name: NSNotification.Name("FloatingZenDraftUpdated"), object: nil)
    }
}

extension FloatingZenManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isVisible = false
        forceAutoSave()
    }
}
