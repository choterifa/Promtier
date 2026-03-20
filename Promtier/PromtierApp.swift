//
//  PromtierApp.swift
//  Promtier
//
//  APP PRINCIPAL: Aplicación macOS menu bar para gestión de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Aumentar el retraso a 3 segundos para dar tiempo al sistema TCC a inicializarse
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true)
        }
        
        // Detect clipboard content and suggest creating a prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkClipboardForPromptSuggestion()
        }
    }
    
    private func checkClipboardForPromptSuggestion() {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string), text.count > 10, text.count < 5000 {
            // Check if it looks like a prompt or if it's just general text
            // Here we just ask if the user wants to create a prompt from it
            
            // For now, we just log it or maybe we can create a notification or alert
            // But since this is a menu bar app, an NSAlert when they click the menu bar might be better
            // Let's store it and show a suggestion banner in the main view
            MenuBarManager.shared.suggestedClipboardContent = text
            MenuBarManager.shared.showPopover()
        }
    }
}

@main
struct PromtierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // CONFIGURABLE: Gestor del menu bar
    @StateObject private var menuBarManager = MenuBarManager.shared
    
    var body: some Scene {
        // CONFIGURABLE: Escena completamente vacía
        EmptyScene()
    }
}

// CONFIGURABLE: Escena que no crea ninguna ventana
struct EmptyScene: Scene {
    var body: some Scene {
        // No crear ninguna ventana en absoluto
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
        .commands {
            // Cmd + , -> Ajustes (abre la sección de preferencias dentro del popover)
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    MenuBarManager.shared.showWithState(.preferences)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
