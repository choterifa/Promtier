//
//  FloatingAIDraftManager.swift
//  Promtier
//
//  SERVICIO: Gestor de ventana flotante para "AI Draft Mode" (Borrador Rápido con IA sin guardar)
//

import SwiftUI
import AppKit
import Combine

class FloatingAIDraftManager: NSObject, ObservableObject {
    static let shared = FloatingAIDraftManager()

    enum ExecutionPhase {
        case idle
        case generating
        case completed
        case failed
    }
    
    private var panel: NSPanel?
    
    @Published var content: String = ""
    @Published var isVisible: Bool = false
    @Published var shouldAutoImprove: Bool = false
    
    // PERSISTENCIA: Resultados y estados para que no se pierdan al cerrar
    @Published var responseText: String = ""
    @Published var isGenerating: Bool = false
    @Published var error: String?
    @Published var isDiffActive: Bool = false
    @Published var isFullSize: Bool = false
    @Published private(set) var executionPhase: ExecutionPhase = .idle
    
    // Historial de la sesión (solo para la instancia actual, no se persiste)
    struct AIDraftHistoryItem: Identifiable, Equatable {
        let id = UUID()
        let input: String
        let output: String
        let timestamp = Date()
    }
    
    @Published var history: [AIDraftHistoryItem] = []
    private var lastHistoryMutationAt: Date = .distantPast
    private let minHistoryMutationInterval: TimeInterval = 0.35
    private var executionTask: Task<Void, Never>?
    private var activeExecutionToken: UUID?
    
    func addToHistory(input: String, output: String) {
        // Evitar duplicados consecutivos exactos
        if let last = history.last, last.input == input && last.output == output {
            return
        }
        
        let newItem = AIDraftHistoryItem(input: input, output: output)
        DispatchQueue.main.async {
            let now = Date()

            // Throttle de mutaciones frecuentes: si llega muy seguido y el input coincide,
            // actualizamos el último item en vez de apilar otro.
            if now.timeIntervalSince(self.lastHistoryMutationAt) < self.minHistoryMutationInterval,
               let lastIndex = self.history.indices.last,
               self.history[lastIndex].input == input {
                self.history[lastIndex] = newItem
                self.lastHistoryMutationAt = now
                return
            }

            self.history.append(newItem)
            // Límite de 15 items para no saturar
            if self.history.count > 15 {
                self.history.removeFirst()
            }
            self.lastHistoryMutationAt = now
        }
    }
    
    private override init() {
        super.init()
    }
    
    func show(content: String = "", autoImprove: Bool = false) {
        if !content.isEmpty {
            self.content = content
        }
        self.shouldAutoImprove = autoImprove
        
        if panel == nil {
            createPanel()
            // Solo centrar la primera vez
            if let screen = NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let panelWidth: CGFloat = 740
                let panelHeight: CGFloat = 570
                let x = visibleFrame.midX - (panelWidth / 2)
                let y = visibleFrame.midY - (panelHeight / 2)
                panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            }
        }

        // Cerrar popover principal para evitar solapamiento
        MenuBarManager.shared.closePopover()

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        // No guardamos nada, esto es "sin entrar"
    }

    func toggleFullSize() {
        isFullSize.toggle()
        HapticService.shared.playLight()
    }

    @MainActor
    func executeDraftTransformation(
        instruction: String,
        content: String,
        imageData: Data? = nil,
        autoCopy: Bool,
        onSuccess: @escaping @MainActor (_ response: String) -> Void,
        onFailure: @escaping @MainActor (_ message: String) -> Void
    ) {
        executionTask?.cancel()

        let token = UUID()
        activeExecutionToken = token
        isGenerating = true
        error = nil
        executionPhase = .generating

        let systemPrompt = composeSystemPrompt(
            instruction: instruction,
            content: content,
            imageData: imageData
        )

        executionTask = Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await AIServiceManager.shared.generate(prompt: systemPrompt, imageData: imageData)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.activeExecutionToken == token else { return }
                    self.isGenerating = false
                    self.executionPhase = .completed
                    self.executionTask = nil
                    if autoCopy {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(response, forType: .string)
                    }
                    onSuccess(response)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.activeExecutionToken == token else { return }
                    let message = error.localizedDescription
                    self.error = message
                    self.isGenerating = false
                    self.executionPhase = .failed
                    self.executionTask = nil
                    onFailure(message)
                }
            }
        }
    }

    @MainActor
    func cancelExecution() {
        executionTask?.cancel()
        executionTask = nil
        activeExecutionToken = nil
        if isGenerating {
            isGenerating = false
        }
        executionPhase = .idle
    }

    private func composeSystemPrompt(instruction: String, content: String, imageData: Data?) -> String {
        if imageData != nil {
            return """
            You are an elite AI Art Director and Vision Assistant. Your task is to act exclusively on the provided image.

            # INSTRUCTION FOR YOU:
            \(instruction)

            # IMPORTANT:
            Respond ONLY with the final transformed or generated prompt based on the image visually speaking. Do not add quotes around it. Do not include introductory text like "Here is the prompt:". Just the raw result.
            """
        }

        return """
        You are an elite Prompt Engineer assistant. Your task is to apply a specific transformation to an existing AI prompt.

        # INSTRUCTION FOR YOU:
        \(instruction)

        # ORIGINAL PROMPT TO EDIT:
        \(content)

        # IMPORTANT:
        Respond ONLY with the final transformed prompt. Do not add quotes around it. Do not include introductory text like "Here is the improved prompt:". Just the raw result.
        """
    }
    
    private func createPanel() {
        class FloatingAIPanel: NSPanel {
            override var canBecomeKey: Bool { return true }
            override var canBecomeMain: Bool { return true }
        }
        
        let newPanel = FloatingAIPanel(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 540),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.masksToBounds = true
        newPanel.contentView?.layer?.cornerRadius = 20
        newPanel.hasShadow = false // Shadow is managed by SwiftUI now
        newPanel.delegate = self
        newPanel.isMovableByWindowBackground = true
        newPanel.center()
        
        let view = FloatingAIDraftView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
            .environmentObject(PromptService.shared)
        
        newPanel.contentView = NSHostingView(rootView: view)
        self.panel = newPanel
    }
}

extension FloatingAIDraftManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Cerrar si pierde el foco (clic fuera) para evitar que vuelva a aparecer al activar la app
        hide()
    }
}
