//
//  MenuBarManager.swift
//  Promtier
//
//  SERVICIO: Gestión del NSStatusItem y popover principal
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit
import Combine

// SERVICIO:// CONFIGURABLE: Gestor del menu bar y popover
class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()
    
    private let menuBarIcon = "text.bubble"
    private let menuBarIconAlt = "text.bubble.fill"
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    @Published var isPopoverShown = false
    @Published var activeViewState: PopoverViewState = .main
    
    enum PopoverViewState {
        case main
        case newPrompt
        case preferences
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Servicios compartidos
    private let promptService = PromptService()
    private let preferencesManager = PreferencesManager.shared
    
    // CONFIGURABLE: Gestor de atajos (inicialización lazy)
    private var shortcutManager: ShortcutManager?
    
    private override init() {
        super.init()
        // CONFIGURABLE: Retrasar inicialización para evitar problemas de orden
        DispatchQueue.main.async {
            self.setupMenuBar()
            self.setupGlobalHotkey()
            self.setupThemeObserver()
        }
    }
    
    deinit {
        // Los atajos se manejan automáticamente por ShortcutManager
    }
    
    // MARK: - Configuración del Menu Bar
    
    /// Configura el NSStatusItem en el menu bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // CONFIGURABLE: Icono y comportamiento
            button.image = NSImage(systemSymbolName: menuBarIcon, accessibilityDescription: "Promtier")
            button.action = #selector(togglePopover)
            button.target = self
            
            // CONFIGURABLE: Efectos visuales
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Tooltip informativo
            button.toolTip = "Promtier - Gestor de Prompts (⌘⇧P)"
        }
    }
    
    /// Alterna la visibilidad del popover
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                activeViewState = .main
                showPopover(relativeTo: button.bounds, of: button)
            }
        } else {
            activeViewState = .main
            showPopover(relativeTo: button.bounds, of: button)
        }
    }
    
    /// Muestra el popover con un estado específico
    func showWithState(_ state: PopoverViewState) {
        guard let button = statusItem?.button else { return }
        self.activeViewState = state
        showPopover(relativeTo: button.bounds, of: button)
        
        // Si es búsqueda, asegurar que el query esté limpio o enfocado (esto se manejará en la vista)
        if state == .main {
            // Podríamos limpiar la búsqueda aquí si quisiéramos
        }
    }
    
    /// Muestra el popover anclado
    private func showPopover(relativeTo rect: NSRect, of view: NSView) {
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 560, height: 480) // CONFIGURABLE: Tamaño modernizado
            popover?.behavior = .transient
            popover?.animates = true
            popover?.delegate = self
            
            // CONFIGURABLE: Vista principal SwiftUI
            let contentView = SearchViewSimple()
                .environmentObject(self.promptService)
                .environmentObject(self.preferencesManager)
                .environmentObject(self)
            
            
            popover?.contentViewController = NSHostingController(rootView: contentView)
            
            // Aplicar apariencia inicial al popover
            updatePopoverAppearance()
        }
        
    
        // Hacer la aplicación activa para evitar requerir doble clic
        NSApp.activate(ignoringOtherApps: true)
        
        popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        
        // Cambiar icono
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIconAlt, 
                                           accessibilityDescription: "Promtier Activo")
        
        isPopoverShown = true
    }
    
    /// Muestra el popover
    func showPopover() {
        guard let button = statusItem?.button else { return }
        activeViewState = .main
        showPopover(relativeTo: button.bounds, of: button)
    }
    
    /// Cierra el popover
    func closePopover() {
        popover?.performClose(nil)
        
        // Restaurar icono normal
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIcon, 
                                           accessibilityDescription: "Promtier")
        
        isPopoverShown = false
    }
    
    // MARK: - Atajos Globales
    
    /// Configura los atajos globales
    private func setupGlobalHotkey() {
        // Inicializar ShortcutManager después de que MenuBarManager esté completamente inicializado
        DispatchQueue.main.async {
            self.shortcutManager = ShortcutManager.shared
            print("✅ Atajos globales configurados")
        }
    }
    
    // MARK: - Launch at Login
    
    // El inicio automático ahora se gestiona directamente en PreferencesManager
    // mediante SMAppService, asegurando persistencia y estados correctos.
    
    // MARK: - Menú Contextual
    
    /// Muestra menú contextual al hacer click derecho
    @objc private func showContextMenu() {
        let menu = NSMenu()
        
        // CONFIGURABLE: Opciones del menú contextual
        menu.addItem(NSMenuItem(title: "Mostrar Promtier", action: #selector(togglePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferencias...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Acerca de Promtier", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func showPreferences() {
        // Abrir ventana de preferencias
        NSApp.sendAction(Selector(("showPreferences:")), to: nil, from: nil)
    }
    
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Gestión de Tema
    
    private func setupThemeObserver() {
        preferencesManager.$appearance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverAppearance()
            }
            .store(in: &cancellables)
    }
    
    private func updatePopoverAppearance() {
        guard let popover = popover else { return }
        
        switch preferencesManager.appearance {
        case .light:
            popover.appearance = NSAppearance(named: .aqua)
        case .dark:
            popover.appearance = NSAppearance(named: .darkAqua)
        case .system:
            popover.appearance = nil // Hereda del sistema
        }
    }
}

// MARK: - NSPopoverDelegate

extension MenuBarManager: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        isPopoverShown = false
        
        // Restaurar icono normal
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIcon, 
                                           accessibilityDescription: "Promtier")
    }
    
    func popoverWillShow(_ notification: Notification) {
        isPopoverShown = true
        
        // Actualizar icono a estado activo
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIconAlt, 
                                           accessibilityDescription: "Promtier Activo")
    }
}

