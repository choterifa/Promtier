//
//  FloatingOnboardingManager.swift
//  Promtier
//
//  SERVICIO: Gestión de la ventana de onboarding (guía inicial)
//

import SwiftUI
import AppKit
import Combine

class FloatingOnboardingManager: NSObject, ObservableObject {
    static let shared = FloatingOnboardingManager()
    
    @Published var isVisible: Bool = false
    @Published var currentStep: Int = 0
    private var panel: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show() {
        // Forzar reset al inicio
        currentStep = 0
        
        if panel == nil {
            createPanel()
        }
        
        // Centrar en pantalla
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        // Marcar como visto al cerrar
        PreferencesManager.shared.hasSeenOnboarding = true
    }
    
    private func createPanel() {
        class OnboardingPanel: NSPanel {
            override var canBecomeKey: Bool { return true }
            override var canBecomeMain: Bool { return true }
        }
        
        let width: CGFloat = 800
        let height: CGFloat = 600
        
        let newPanel = OnboardingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        
        // Efecto de esquina
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.cornerRadius = 24
        newPanel.contentView?.layer?.masksToBounds = true
        
        let view = OnboardingView()
            .environmentObject(self)
            .environmentObject(PreferencesManager.shared)
        
        newPanel.contentView = NSHostingView(rootView: view)
        self.panel = newPanel
    }
}
