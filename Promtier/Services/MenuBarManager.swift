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
    private var ghostWindow: NSPanel?
    
    @Published var isPopoverShown = false
    @Published var activeViewState: PopoverViewState = .main {
        didSet {
            updatePopoverBehavior()
        }
    }
    @Published var folderToEdit: Folder? = nil
    @Published var isModalActive: Bool = false {
        didSet {
            updatePopoverBehavior()
        }
    }
    
    enum PopoverViewState {
        case main
        case newPrompt
        case preferences
        case folderManager
        case trash
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Servicios compartidos
    private let promptService = PromptService()
    private let preferencesManager = PreferencesManager.shared
    
    // CONFIGURABLE: Gestor de atajos (inicialización lazy)
    private var shortcutManager: ShortcutManager?
    
    // CONFIGURABLE: Operaciones en lote
    @Published var batchService = BatchOperationsService()
    
    private override init() {
        super.init()

        // Cerrar el popover cuando la app pierde foco (evita quedarse "gris" al hacer click fuera)
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.popover?.isShown == true else { return }
                self.closePopover()
            }
            .store(in: &cancellables)

        // CONFIGURABLE: Retrasar inicialización para evitar problemas de orden
        DispatchQueue.main.async {
            self.setupMenuBar()
            self.setupGlobalHotkey()
            self.setupThemeObserver()
            self.setupDimensionObserver()
            
            // RESTAURACIÓN DE ESTADO: Abrir en modo nuevo prompt si hay un borrador
            if DraftService.shared.hasDraft {
                self.activeViewState = .newPrompt
                self.isModalActive = true
            }
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
            
            // CONFIGURABLE: Solo permitir click izquierdo para mayor estabilidad
            button.sendAction(on: [.leftMouseUp])
            
            // Tooltip informativo
            button.toolTip = "Promtier - Gestor de Prompts (⌘⇧P)"
        }
    }
    
    /// Alterna la visibilidad del popover o cierra modales activos
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            // Si estábamos en NewPrompt pero se cerró (clic fuera o ESC), reabrimos ahí.
            // Solo forzamos .main si no había borradores y ya estábamos ahí.
            if !DraftService.shared.hasDraft && activeViewState == .main {
                activeViewState = .main
            }
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
            popover?.contentSize = NSSize(width: preferencesManager.windowWidth, height: preferencesManager.windowHeight)
            popover?.behavior = .transient
            popover?.animates = true
            popover?.delegate = self
            
            // CONFIGURABLE: Vista principal SwiftUI
            let contentView = SearchViewSimple()
                .environmentObject(self.promptService)
                .environmentObject(self.preferencesManager)
                .environmentObject(self.batchService)
                .environmentObject(self)
                .environment(\.locale, Locale(identifier: self.preferencesManager.language.rawValue))
            
            popover?.contentViewController = NSHostingController(rootView: AnyView(contentView))
            
            // Aplicar apariencia inicial al popover
            updatePopoverAppearance()
        }
        
    
        popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        
        // Asegurar foco inmediato para evitar el "doble click"
        if let window = popover?.contentViewController?.view.window {
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
        
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
        
        // Limpiar estado modal si existiera al cerrar
        isModalActive = false
    }
    
    /// Repara el comportamiento transitorio del popover tras cerrar un modal o sheet
    func fixTransientState() {
        guard let popover = popover else { return }
        // Forzar un ciclo de actualización del comportamiento para reactivar los monitores de eventos internos de AppKit
        popover.behavior = .applicationDefined
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            popover.behavior = .transient
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
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
            
        // Observar cambio de idioma para refrescar la UI
        preferencesManager.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshPopoverRootView()
            }
            .store(in: &cancellables)
    }
    
    private func refreshPopoverRootView() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        let contentView = SearchViewSimple()
            .environmentObject(self.promptService)
            .environmentObject(self.preferencesManager)
            .environmentObject(self.batchService)
            .environmentObject(self)
            .environment(\.locale, Locale(identifier: self.preferencesManager.language.rawValue))
            
        // CORRECCIÓN: No reemplazar el controller, solo actualizar la rootView
        // Esto evita que el popover se cierre y reabra internamente
        if let hostingController = popover.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = AnyView(contentView)
        } else {
            popover.contentViewController = NSHostingController(rootView: AnyView(contentView))
        }
        
        // CORRECCIÓN: Forzar reposicionamiento centrado si ya está visible
        if popover.isShown {
            DispatchQueue.main.async {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
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
    
    private func setupDimensionObserver() {
        // Observar ancho/alto para la ventana real
        Publishers.CombineLatest(preferencesManager.$windowWidth, preferencesManager.$windowHeight)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] width, height in
                self?.updatePopoverSize(width: width, height: height)
            }
            .store(in: &cancellables)
            
        // Observar estado de redimensionado para la Ventana Fantasma (Ghost Window)
        preferencesManager.$isResizingVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                if isVisible {
                    self?.showGhostWindow()
                } else {
                    self?.hideGhostWindow()
                }
            }
            .store(in: &cancellables)
            
        // Observar dimensiones proyectadas para sincronizar la Ventana Fantasma
        Publishers.CombineLatest(preferencesManager.$previewWidth, preferencesManager.$previewHeight)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] width, height in
                self?.updateGhostWindowSize(width: width, height: height)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Gestión de Ghost Window (Guía Visual Externa)
    
    private func showGhostWindow() {
        guard let button = statusItem?.button, let _ = button.window else { return }
        
        if ghostWindow == nil {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true // No interferir con los sliders
            
            // Contenido visual: un simple borde azul traslúcido
            let view = NSView()
            view.wantsLayer = true
            view.layer?.cornerRadius = 16
            view.layer?.borderWidth = 3
            view.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
            view.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.05).cgColor
            
            panel.contentView = view
            self.ghostWindow = panel
        }
        
        updateGhostWindowSize(width: preferencesManager.previewWidth, height: preferencesManager.previewHeight)
        ghostWindow?.orderFrontRegardless()
    }
    
    private func hideGhostWindow() {
        ghostWindow?.orderOut(nil)
    }
    
    private func updateGhostWindowSize(width: CGFloat, height: CGFloat) {
        guard let ghost = ghostWindow, let button = statusItem?.button, let buttonWindow = button.window else { return }
        
        // Calcular posición centrada respecto al icono del menu bar
        let buttonFrame = buttonWindow.frame
        let newX = buttonFrame.midX - (width / 2)
        
        // Ajuste vertical: La flecha del popover suele tener ~14px.
        // Restamos el offset para que el marco azul coincida con el borde blanco real.
        let arrowOffset: CGFloat = 14
        let newY = buttonFrame.minY - height - arrowOffset 
        
        ghost.setFrame(NSRect(x: newX, y: newY, width: width, height: height), display: true, animate: false)
    }
    
    private func updatePopoverSize(width: CGFloat, height: CGFloat) {
        popover?.contentSize = NSSize(width: width, height: height)
    }
    
    /// Actualiza el comportamiento del popover basado en el estado
    private func updatePopoverBehavior() {
        guard let popover = popover else { return }
        
        // CAMBIO: Ahora permitimos que el popover siempre sea transitorio (.transient)
        // para que se cierre con ESC o clic fuera, pero mantenemos el estado
        // en activeViewState para que al reabrir regrese a la misma pantalla.
        popover.behavior = .transient
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
        
        // Comprobación rápida de permisos al abrir el popover
        ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: false)
        
        // Actualizar icono a estado activo
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIconAlt, 
                                           accessibilityDescription: "Promtier Activo")
    }
}
