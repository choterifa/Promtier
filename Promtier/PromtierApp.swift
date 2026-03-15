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

@main
struct PromtierApp: App {
    
    // CONFIGURABLE: Gestor del menu bar
    @StateObject private var menuBarManager = MenuBarManager.shared
    
    var body: some Scene {
        // CONFIGURABLE: Escena completamente vacía - sin ventanas
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
            // Vaciar comandos para no mostrar menú
        }
    }
}
