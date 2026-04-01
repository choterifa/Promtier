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
    static let secondary = FloatingZenManager() // Segunda instancia para soportar hasta 2 prompts
    
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
    @Published var isCollapsed: Bool = false
    
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
    
    func show(title: String, promptDescription: String, content: String, showcaseImages: [Data] = [], promptId: UUID?, isEditing: Bool) {
        self.title = title
        self.promptDescription = promptDescription
        self.content = content
        self.originalPromptId = promptId
        self.isEditingExisting = isEditing
        self.showcaseImages = showcaseImages
        self.lastSaveSuccess = false
        
        // Save initial state to detect changes later
        self.initialTitle = title
        self.initialDescription = promptDescription
        self.initialContent = content
        self.initialImages = showcaseImages
        
        if panel == nil { createPanel() }
        
        // Posicionar a la derecha y centrada verticalmente
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let panelWidth: CGFloat = 440
            let panelHeight: CGFloat = 500
            
            // Revert a centrado horizontal y vertical
            let x = visibleFrame.midX - (panelWidth / 2)
            let y = visibleFrame.midY - (panelHeight / 2)
            
            panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func bringToFront() {
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
    
    /// Auto-completa la clasificación, título y descripción si hay una IA habilitada
    func performMagic() {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let prefs = PreferencesManager.shared
        let hasAI = (!prefs.openAIApiKey.isEmpty && prefs.openAIEnabled) || (!prefs.geminiAPIKey.isEmpty && prefs.geminiEnabled)
        guard hasAI else { return }
        
        let currentTitle = self.title
        let currentContent = self.content
        let currentDescription = self.promptDescription
        let currentFolder = self.selectedFolder
        let folders = PromptService.shared.folders.map { $0.name }
        
        Task {
            await MainActor.run { self.isClassifying = true }
            
            async let catTask: String? = {
                if currentFolder != nil { return nil }
                return await self.classifyCurrentPrompt(title: currentTitle, content: currentContent, folders: folders)
            }()
            
            async let titleTask: String? = {
                if !currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                return await self.generateMagicField(type: "short title (maximum 50 characters)", content: currentContent)
            }()
            
            async let descTask: String? = {
                if !currentDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                return await self.generateMagicField(type: "short description (maximum 100 characters)", content: currentContent)
            }()
            
            let (newCat, newTitle, newDesc) = await (catTask, titleTask, descTask)
            
            await MainActor.run {
                if let nc = newCat { self.selectedFolder = nc }
                if let nt = newTitle { self.title = nt }
                if let nd = newDesc { self.promptDescription = nd }
                self.isClassifying = false
            }
        }
    }
    
    private func generateMagicField(type: String, content: String) async -> String? {
        let prefs = PreferencesManager.shared
        let systemPrompt = """
        You are an assistant. Based on the following prompt content, generate a \(type) in the same language as the content.
        Respond ONLY with the generated text, without quotes, extra punctuation, or trailing periods.
        
        Content:
        \(content)
        """
        
        do {
            let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
            
            var final = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if final.hasPrefix("\"") && final.hasSuffix("\"") {
                final.removeFirst()
                final.removeLast()
            }
            return final
        } catch {
            print("❌ Magic Generate Field Error: \(error.localizedDescription)")
            return nil
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
        
        do {
            let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
            
            let final = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if folders.contains(final) {
                return final
            }
            return nil
        } catch {
            print("❌ Magic Classify Error: \(error.localizedDescription)")
            return nil
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
    
    func toggleCollapse() {
        guard let panel = panel else { return }
        isCollapsed.toggle()
        
        let targetWidth: CGFloat = isCollapsed ? 48 : 440
        let targetHeight: CGFloat = isCollapsed ? 48 : 500
        
        var frame = panel.frame
        let oldWidth = frame.size.width
        let oldHeight = frame.size.height
        
        let diffW = targetWidth - oldWidth
        let diffH = targetHeight - oldHeight
        
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        frame.origin.x -= diffW / 2 // Centrar horizontalmente respecto al punto anterior
        frame.origin.y -= diffH / 2 // Centrar verticalmente respecto al punto anterior
        
        // Clamping para que no se salga de la pantalla al abrir cerca del borde
        if !isCollapsed, let screen = panel.screen ?? NSScreen.main {
            let visibleRect = screen.visibleFrame
            let margin: CGFloat = 16
            
            let minX = visibleRect.minX + margin
            let minY = visibleRect.minY + margin
            let maxX = visibleRect.maxX - targetWidth - margin
            let maxY = visibleRect.maxY - targetHeight - margin
            
            frame.origin.x = max(minX, min(frame.origin.x, maxX))
            frame.origin.y = max(minY, min(frame.origin.y, maxY))
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
            // Anima el enmascaramiento de AppKit para que no haya picos al rebotar
            panel.contentView?.layer?.cornerRadius = isCollapsed ? 24 : 16
        }
    }
    
    private func createPanel() {
        class FloatingZenPanel: NSPanel {
            override var canBecomeKey: Bool {
                return true
            }
            override var canBecomeMain: Bool {
                return true
            }
        }
        
        let newPanel = FloatingZenPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newPanel.minSize = NSSize(width: 400, height: 450)
        newPanel.maxSize = NSSize(width: 1200, height: 1000)
        
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.masksToBounds = true
        newPanel.contentView?.layer?.cornerRadius = 16
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
