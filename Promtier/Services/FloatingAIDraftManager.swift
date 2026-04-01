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
    
    private var panel: NSPanel?
    
    @Published var content: String = ""
    @Published var isVisible: Bool = false
    @Published var shouldAutoImprove: Bool = false
    
    // PERSISTENCIA: Resultados y estados para que no se pierdan al cerrar
    @Published var responseText: String = ""
    @Published var responseTextGemini: String = ""
    @Published var responseTextOpenAI: String = ""
    @Published var isGenerating: Bool = false
    @Published var isGeneratingGemini: Bool = false
    @Published var isGeneratingOpenAI: Bool = false
    @Published var error: String?
    @Published var isCompareMode: Bool = false
    @Published var isDiffActive: Bool = false
    
    // Historial de la sesión (solo para la instancia actual, no se persiste)
    struct AIDraftHistoryItem: Identifiable, Equatable {
        let id = UUID()
        let input: String
        let output: String
        let timestamp = Date()
    }
    
    @Published var history: [AIDraftHistoryItem] = []
    
    func addToHistory(input: String, output: String) {
        // Evitar duplicados consecutivos exactos
        if let last = history.last, last.input == input && last.output == output {
            return
        }
        
        let newItem = AIDraftHistoryItem(input: input, output: output)
        DispatchQueue.main.async {
            self.history.append(newItem)
            // Límite de 15 items para no saturar
            if self.history.count > 15 {
                self.history.removeFirst()
            }
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
                let panelWidth: CGFloat = isCompareMode ? 1115 : 740
                let panelHeight: CGFloat = 570
                let x = visibleFrame.midX - (panelWidth / 2)
                let y = visibleFrame.midY - (panelHeight / 2)
                panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            }
        }
        
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        // No guardamos nada, esto es "sin entrar"
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
        newPanel.hidesOnDeactivate = true // Cierra al hacer click fuera
        newPanel.center()
        
        let view = FloatingAIDraftView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
        
        newPanel.contentView = NSHostingView(rootView: view)
        self.panel = newPanel
    }
}

extension FloatingAIDraftManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}
