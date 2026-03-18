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
