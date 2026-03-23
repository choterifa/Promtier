//
//  OmniSearchManager.swift
//  Promtier
//
//  SERVICIO: Gestión de la ventana de búsqueda Omni (estilo Spotlight)
//

import SwiftUI
import AppKit
import Combine

class OmniSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Spotlight-like windows often override this
    override var acceptsFirstResponder: Bool { true }
}

class OmniSearchManager: NSObject, ObservableObject {
    static let shared = OmniSearchManager()
    
    private var panel: OmniSearchPanel?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var previousApp: NSRunningApplication?
    
    @Published var isVisible: Bool = false
    
    private override init() {
        super.init()
        setupGlobalMonitor()
    }
    
    private func setupGlobalMonitor() {
        // Monitor local para capturar flechas y escape globalmente cuando el panel esté activo
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            
            // Log de depuración interna (invisible para el usuario)
            let keyCode = event.keyCode
            
            if keyCode == 125 { // Down
                NotificationCenter.default.post(name: NSNotification.Name("OmniSearchMove"), object: "down")
                return nil // Bloquear para que el TextField no mueva el cursor
            } else if keyCode == 126 { // Up
                NotificationCenter.default.post(name: NSNotification.Name("OmniSearchMove"), object: "up")
                return nil // Bloquear
            } else if keyCode == 36 || keyCode == 76 { // Enter / Return
                NotificationCenter.default.post(name: NSNotification.Name("OmniSearchSubmit"), object: nil)
                return nil // Capturar para procesar en la vista
            } else if keyCode == 53 { // Esc
                // Ya no cerramos con Esc por petición del usuario, sino que quitamos foco en la vista
                return event 
            }
            
            return event
        }
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
        
        // Guardar la app activa anterior para devolver el foco al cerrar
        if let frontApp = NSWorkspace.shared.frontmostApplication, 
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
        }
        
        // Centrar en pantalla (Centro real 0.5)
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelSize = panel?.frame.size ?? NSSize(width: 650, height: 450)
            let newFrame = NSRect(
                x: screenRect.origin.x + (screenRect.width - panelSize.width) / 2,
                y: screenRect.origin.y + (screenRect.height - panelSize.height) / 2,
                width: panelSize.width,
                height: panelSize.height
            )
            panel?.setFrame(newFrame, display: true)
        }
        
        // ACTIVACIÓN AGRESIVA: 
        // 1. Asegurar que la app sea activa
        NSApp.activate()
        
        // 2. Mostrar y forzar "Key" window
        panel?.makeKeyAndOrderFront(nil)
        
        // 3. Pequeño delay para re-asegurar el foco tras la animación de orden frontal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.panel?.makeKey()
            self.isVisible = true
            NotificationCenter.default.post(name: NSNotification.Name("OmniSearchOpened"), object: nil)
        }
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        
        // Devolver el foco a la aplicación anterior
        if let previousApp = previousApp {
            previousApp.activate()
            self.previousApp = nil
        }
    }
    
    private func createPanel() {
        let newPanel = OmniSearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
            styleMask: [.borderless], 
            backing: .buffered,
            defer: false
        )
        
        newPanel.isMovableByWindowBackground = true
        newPanel.isFloatingPanel = true
        newPanel.level = .mainMenu + 1
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.delegate = self
        newPanel.hidesOnDeactivate = true 
        newPanel.isReleasedWhenClosed = false
        newPanel.acceptsMouseMovedEvents = true
        
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
        // Cerrar si pierde el foco (clic fuera)
        hide()
    }
}
