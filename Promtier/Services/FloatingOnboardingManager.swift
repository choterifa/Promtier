//
//  FloatingOnboardingManager.swift
//  Promtier
//
//  SERVICIO: Gestión de la ventana de onboarding (guía inicial)
//

import SwiftUI
import AppKit
import Combine
import QuartzCore

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
        panel?.alphaValue = 0
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
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

        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.cornerRadius = 24
        hostingView.layer?.masksToBounds = true

        newPanel.contentView = hostingView
        self.panel = newPanel
    }
}
