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
            ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: false)
            
            // Mostrar Onboarding en primer lanzamiento
            if !PreferencesManager.shared.hasSeenOnboarding {
                FloatingOnboardingManager.shared.show()
            }
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
        // Evitar crear una ventana “vacía” al lanzar (menu bar app).
        Settings {
            EmptyView()
        }
        .commands {
            // Cmd + N -> Nuevo Prompt
            // Cmd + Shift + N -> Nueva Categoría
            CommandGroup(replacing: .newItem) {
                Button("new_prompt".localized(for: PreferencesManager.shared.language)) {
                    // Resetear el prompt seleccionado para que sea uno nuevo
                    MenuBarManager.shared.showWithState(.newPrompt)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("create_category".localized(for: PreferencesManager.shared.language)) {
                    MenuBarManager.shared.folderToEdit = nil
                    MenuBarManager.shared.showWithState(.folderManager)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            
            // Comandos estándar de edición para Undo/Redo
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])
                
                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
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
