//
//  OmniSearchManager.swift
//  Promtier
//
//  SERVICIO: Gestión de la ventana de búsqueda Omni (estilo Spotlight)
//

import SwiftUI
import AppKit
import Combine

class OmniSearchManager: NSObject, ObservableObject {
    static let shared = OmniSearchManager()
    
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isVisible: Bool = false
    
    private override init() {
        super.init()
    }
    
    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        if panel == nil {
            createPanel()
        }
        
        // Posicionar siempre en el centro de la pantalla actual
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelSize = panel?.frame.size ?? NSSize(width: 650, height: 450)
            let newFrame = NSRect(
                x: screenRect.origin.x + (screenRect.width - panelSize.width) / 2,
                y: screenRect.origin.y + (screenRect.height - panelSize.height) * 0.7,
                width: panelSize.width,
                height: panelSize.height
            )
            panel?.setFrame(newFrame, display: true)
        }
        
        // IMPORTANTE: Primero activar la app, luego mostrar ventana
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        
        // Pequeño delay para asegurar que el sistema otorgó el foco antes de marcar como visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.panel?.makeKey()
            self.isVisible = true
            // Notificar para resetear búsqueda
            NotificationCenter.default.post(name: NSNotification.Name("OmniSearchOpened"), object: nil)
        }
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }
    
    private func createPanel() {
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
            styleMask: [.borderless, .nonactivatingPanel], // Regresamos a nonactivating pero con manejo manual de foco
            backing: .buffered,
            defer: false
        )
        
        newPanel.isFloatingPanel = true
        newPanel.level = .mainMenu + 1 // Nivel de Spotlight
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.delegate = self
        newPanel.hidesOnDeactivate = true 
        newPanel.isReleasedWhenClosed = false
        let view = OmniSearchView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
            .environmentObject(PromptService.shared)
        
        newPanel.contentView = NSHostingView(rootView: view)
        self.panel = newPanel
    }
}

extension OmniSearchManager: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
