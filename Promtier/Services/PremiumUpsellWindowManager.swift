//
//  PremiumUpsellWindowManager.swift
//  Promtier
//
//  Gestor para mostrar la ventana de compras Pro de forma independiente
//

import SwiftUI
import AppKit

class PremiumUpsellWindowManager: NSObject, NSWindowDelegate {
    static let shared = PremiumUpsellWindowManager()
    
    private var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show(featureName: String) {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        class UpsellPanel: NSPanel {
            override var canBecomeKey: Bool { return true }
            override var canBecomeMain: Bool { return true }
        }
        
        let newWindow = UpsellPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isMovableByWindowBackground = true
        newWindow.isFloatingPanel = true
        newWindow.level = .floating
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        
        let view = PremiumUpsellView(
            featureName: featureName,
            onCancel: { [weak self] in
                self?.close()
            }
        )
        .environmentObject(PreferencesManager.shared)
        
        let hostingView = NSHostingView(rootView: view)
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        MenuBarManager.shared.closePopover()
        
        self.window = newWindow
    }
    
    func close() {
        window?.close()
        window = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
