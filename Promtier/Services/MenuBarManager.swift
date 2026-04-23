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
    
    func navigateToPrompt(id: UUID) {
        // 1. Asegurar que el popover esté abierto
        if popover?.isShown == false {
            showPopover()
        }
        
        // 2. Cambiar a la vista principal si estamos en otro sitio
        if activeViewState != .main {
            activeViewState = .main
        }
        
        // 3. Emitir la señal de navegación que las vistas observarán
        self.promptIdToNavigate = id
    }
    
    private let menuBarIcon = "text.bubble.fill"
    private let menuBarIconAlt = "text.bubble.fill"
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var ghostWindow: NSPanel?
    private var floatingZenWindow: NSPanel?
    private var eventMonitorId: UUID?
    
    @Published var isPopoverShown = false
    @Published var activeViewState: PopoverViewState = .main {
        didSet {
            updatePopoverBehavior()
            // Persistir el estado para que sobreviva a reinicios
            UserDefaults.standard.set(activeViewState.rawValue, forKey: "lastNavigatedViewState")
            
            // When returning to main, reset old suggestion so it can be re-triggered
            if activeViewState == .main && oldValue != .main {
                suggestedClipboardContent = nil
            }
            if activeViewState != .newPrompt {
                promptToEditFromOmniSearch = nil
            }
        }
    }
    @Published var folderToEdit: Folder? = nil
    @Published var parentFolderIdForNewCategory: UUID? = nil
    @Published var promptToEditFromOmniSearch: Prompt? = nil
    @Published var suggestedClipboardContent: String? = nil
    @Published var promptIdToNavigate: UUID? = nil
    @Published var isModalActive: Bool = false {
        didSet {
            updatePopoverBehavior()
        }
    }
    
    // Estado de hover compartido para la sidebar y su tirador de redimensionamiento
    @Published var isSidebarHovered = false
    
    // CONTROL DE FRECUENCIA: Último texto sugerido (para no repetir el banner si el popover se abre varias veces)
    private var lastSuggestedText: String? = nil
    private var lastSuggestedCount: Int = 0
    
    enum PopoverViewState: String {
        case main = "main"
        case newPrompt = "newPrompt"
        case preferences = "preferences"
        case folderManager = "folderManager"
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var sidebarHoverTask: AnyCancellable?
    
    // Servicios compartidos
    private let promptService = PromptService.shared
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
                if self.isModalActive { return }
                self.closePopover()
            }
            .store(in: &cancellables)

        // CONFIGURABLE: Retrasar inicialización para evitar problemas de orden
        DispatchQueue.main.async {
            self.setupMenuBar()
            self.setupGlobalHotkey()
            self.setupThemeObserver()
            self.setupDimensionObserver()
            
            // RESTAURACIÓN DE ESTADO: Recuperar última vista guardada
            if let lastViewRaw = UserDefaults.standard.string(forKey: "lastNavigatedViewState"),
               let lastView = PopoverViewState(rawValue: lastViewRaw) {
                self.activeViewState = lastView
            }
            
            // Prioridad crítica: Abrir en modo nuevo prompt si hay un borrador
            if DraftService.shared.hasDraft {
                self.activeViewState = .newPrompt
                self.isModalActive = false
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
            
            // CONFIGURABLE: Permitir click izquierdo y derecho
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Tooltip informativo
            button.toolTip = "Promtier - Gestor de Prompts (⌘⇧P)"
        }
    }
    
    /// Alterna la visibilidad del popover o cierra modales activos
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        
        if isRightClick {
            showContextMenu()
            return
        }
        
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            // Siempre abrir desde la página principal, a menos que haya
            // un borrador activo o se esté editando un prompt.
            if DraftService.shared.hasDraft {
                activeViewState = .newPrompt
            } else if activeViewState != .main {
                activeViewState = .main
            }
            
            closeFloatingWindows()

            // Sugerir desde el portapapeles si está habilitado y estamos en la vista principal
            if activeViewState == .main {                // CAPTURAR APP ACTIVA PARA CONTEXTO
                if let frontApp = NSWorkspace.shared.frontmostApplication,
                   frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                    promptService.activeAppBundleID = frontApp.bundleIdentifier
                }
                checkClipboardForPromptSuggestion()
            }
            
            showPopover(relativeTo: button.bounds, of: button)
        }
    }
    
    /// Muestra el popover con un estado específico
    func showWithState(_ state: PopoverViewState) {
        guard let button = statusItem?.button else { return }
        
        // Aplicar animación de entrada suave (igual que cuando se hace clic)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.activeViewState = state
            self.isModalActive = (state == .folderManager)
        }

        closeFloatingWindows()

        showPopover(relativeTo: button.bounds, of: button)        
        // Si es búsqueda, asegurar que el query esté limpio o enfocado (esto se manejará en la vista)
        if state == .main {
            // Podríamos limpiar la búsqueda aquí si quisiéramos
        }
    }
    
    func closeFloatingWindows() {
        let sharedZen = FloatingZenManager.shared
        let secondaryZen = FloatingZenManager.secondary
        let sharedDraft = FloatingAIDraftManager.shared
        let sharedOmni = OmniSearchManager.shared

        if sharedZen.isVisible { sharedZen.hide() }
        if secondaryZen.isVisible { secondaryZen.hide() }
        if sharedDraft.isVisible { sharedDraft.hide() }
        if sharedOmni.isVisible { sharedOmni.hide() }
    }    
    /// Muestra el popover anclado
    private func showPopover(relativeTo rect: NSRect, of view: NSView) {
        if popover == nil {
            popover = NSPopover()
            let size = NSSize(width: preferencesManager.windowWidth, height: preferencesManager.windowHeight)
            popover?.contentSize = size
            popover?.behavior = .transient
            popover?.animates = true
            popover?.delegate = self
            
            // CONFIGURABLE: Vista principal SwiftUI
            let contentView = PopoverContainerView()
                .environmentObject(self.promptService)
                .environmentObject(self.preferencesManager)
                .environmentObject(self.batchService)
                .environmentObject(self)
            
            let controller = NSHostingController(rootView: AnyView(contentView))
            controller.view.frame.size = size
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            popover?.contentViewController = controller
            popover?.contentViewController?.preferredContentSize = size
            
            // Aplicar apariencia inicial al popover
            updatePopoverAppearance()
        }
        
        // Asegurar tamaño correcto incluso en el primer show (evita que el popover “crezca” por layout inicial).
        updatePopoverSize(width: preferencesManager.windowWidth, height: preferencesManager.windowHeight)

        popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        
        // Asegurar foco inmediato para evitar el "doble click"
        if let window = popover?.contentViewController?.view.window {
            window.backgroundColor = NSColor.windowBackgroundColor
            window.isOpaque = true
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
        
        // Cambiar icono
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIconAlt, 
                                           accessibilityDescription: "Promtier Activo")
        
        isPopoverShown = true
        startEventMonitoring()
    }
    
    /// Muestra el popover
    func showPopover() {
        guard let button = statusItem?.button else { return }
        
        // Solo cambiamos automáticamente si hay un borrador que requiere atención
        if DraftService.shared.hasDraft && suggestedClipboardContent == nil {
            activeViewState = .newPrompt
            isModalActive = false
        } else {
            // En cualquier otro caso, MANTENEMOS el activeViewState donde estaba.
            // Solo verificamos el portapapeles si estamos en la vista principal
            if activeViewState == .main {
                checkClipboardForPromptSuggestion()
            }
        }
        
        showPopover(relativeTo: button.bounds, of: button)
    }
    
    /// Verifica el portapapeles para sugerir la creación de un prompt
    func checkClipboardForPromptSuggestion() {
        guard preferencesManager.clipboardSuggestions else { return }
        
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string), 
           text.count > 10, text.count < 5000 {
            
            // Si el texto es igual al último sugerido, solo lo permitimos una vez
            if text == lastSuggestedText && lastSuggestedCount >= 1 {
                return 
            }
            
            // CONTEXTO: Filtrar origen (Navegadores o Apps permitidas)
            // Obtenemos el ID de la app de donde viene el copiado
            let sourceID = ClipboardService.shared.lastSourceAppBundleID ?? ""
            let isBrowser = preferencesManager.browserBundleIDs.contains(sourceID)
            let isCustomAllowed = preferencesManager.customAllowedAppBundleIDs.contains(sourceID)
            
            // Si la restricción está activa (por defecto true), bloqueamos si no es una app autorizada
            if preferencesManager.onlySuggestFromBrowsers {
                if !isBrowser && !isCustomAllowed {
                    return // No es una fuente autorizada, ignoramos la sugerencia
                }
            }
            
            // Solo sugerir si no hay un borrador activo (para no interrumpir)
            guard !DraftService.shared.hasDraft else { return }
            
            if text != lastSuggestedText {
                self.lastSuggestedCount = 1
            } else {
                self.lastSuggestedCount += 1
            }
            
            self.suggestedClipboardContent = text
            self.lastSuggestedText = text
            
            // Auto-hide suggestion after 4.3 seconds to be less intrusive
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.suggestedClipboardContent == text {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.suggestedClipboardContent = nil
                    }
                }
            }
        }
    }
    
    /// Cierra el popover
    func closePopover() {
        popover?.performClose(nil)
        
        // Safety: si el HUD/ghost window quedó visible por algún bug, ocultarlo al cerrar.
        preferencesManager.isResizingVisible = false
        hideGhostWindow()
        
        // Restaurar icono normal
        statusItem?.button?.image = NSImage(systemSymbolName: menuBarIcon, 
                                           accessibilityDescription: "Promtier")
        
        isPopoverShown = false
        
        // Limpiar estado modal si existiera al cerrar
        isModalActive = false
        stopEventMonitoring()
    }
    
    /// Repara el comportamiento transitorio del popover tras cerrar un modal o sheet
    func fixTransientState() {
        guard let popover = popover else { return }
        // Forzar un ciclo de actualización del comportamiento para reactivar los monitores de eventos internos de AppKit
        popover.behavior = .applicationDefined
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updatePopoverBehavior()
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
        let lang = preferencesManager.language
        
        // CONFIGURABLE: Opciones del menú contextual con target explícito
        func addMenuItem(_ title: String, selector: Selector, key: String = "") {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        
        addMenuItem("new_prompt".localized(for: lang), selector: #selector(showAddPrompt), key: "n")
        
        // Atajo dinámico para Fast Add
        let fastAddShortcut = preferencesManager.shortcutDisplayString(keyCode: preferencesManager.fastAddHotkeyCode, modifiers: preferencesManager.fastAddHotkeyModifiers)
        addMenuItem("\("gt_fast_add_title".localized(for: lang)) \(fastAddShortcut)", selector: #selector(showFastAdd))
        
        menu.addItem(NSMenuItem.separator())
        addMenuItem("\("settings".localized(for: lang))...", selector: #selector(showPreferences), key: ",")
        addMenuItem("\("welcome_guide".localized(for: lang))...", selector: #selector(showOnboarding))
        menu.addItem(NSMenuItem.separator())
        addMenuItem("about_promtier".localized(for: lang), selector: #selector(showAbout))
        menu.addItem(NSMenuItem.separator())
        addMenuItem("quit".localized(for: lang), selector: #selector(quitApp), key: "q")
        
        // Mostrar el menú de forma síncrona
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        // Limpiar para que el click izquierdo vuelva a funcionar con togglePopover
        DispatchQueue.main.async {
            self.statusItem?.menu = nil
        }
    }
    
    @objc private func showAddPrompt() {
        // Force the app to open the new prompt view
        showWithState(.newPrompt)
    }
    
    @objc private func showFastAdd() {
        let shared = FloatingZenManager.shared
        let secondary = FloatingZenManager.secondary
        
        if !shared.isVisible || !shared.hasUnsavedChanges {
            shared.show(title: "", promptDescription: "", content: "", promptId: nil, isEditing: false)
        } else if !secondary.isVisible || !secondary.hasUnsavedChanges {
            secondary.show(title: "", promptDescription: "", content: "", promptId: nil, isEditing: false)
        } else {
            secondary.bringToFront()
        }
    }
    
    @objc private func showPreferences() {
        // Abrir la vista de preferencias dentro del popover
        showWithState(.preferences)
    }
    
    @objc private func showOnboarding() {
        // Relanzar la guía de bienvenida
        FloatingOnboardingManager.shared.show()
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
    
    private func setupDimensionObserver() {
        // Observar ancho/alto para la ventana real
        Publishers.CombineLatest(preferencesManager.$windowWidth, preferencesManager.$windowHeight)
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
        let size = NSSize(width: width, height: height)
        popover?.contentSize = size
        popover?.contentViewController?.preferredContentSize = size
        popover?.contentViewController?.view.frame.size = size
    }
    
    /// Actualiza el comportamiento del popover basado en el estado
    private func updatePopoverBehavior() {
        guard let popover = popover else { return }
        
        if isModalActive {
            // BLOQUEO: Reservado para flujos que sí requieren mantener el popover fijo
            popover.behavior = .applicationDefined
        } else {
            // NORMAL: Se cierra automáticamente al perder el foco
            popover.behavior = .transient
        }
    }

    // MARK: - Event Monitoring

    /// Gestiona el estado de hover de la sidebar con retrasos premium para evitar triggers accidentales
    func setSidebarHovered(_ hovered: Bool) {
        sidebarHoverTask?.cancel()
        
        if hovered {
            if !isSidebarHovered {
                // Retraso de 0.7s para mostrar: Evita aperturas si el usuario solo está cruzando el ratón (comportamiento premium)
                sidebarHoverTask = Just(())
                    .delay(for: .seconds(0.7), scheduler: RunLoop.main)
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        // Animación más instantánea (0.15s) después de la espera
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                            self.isSidebarHovered = true
                        }
                    }
            }
        } else {
            // Retraso de 0.25s para ocultar: "Perdona" si el usuario saca el ratón sin querer por un instante
            sidebarHoverTask = Just(())
                .delay(for: .seconds(0.25), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.isSidebarHovered = false
                    }
                }
        }
    }

    private func startEventMonitoring() {
        guard eventMonitorId == nil else { return }

        eventMonitorId = GlobalHotkeyManager.shared.subscribeToGlobalEvents { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else { return }
            if self.isModalActive { return }
            self.closePopover()
        }    }

    private func stopEventMonitoring() {
        if let id = eventMonitorId {
            GlobalHotkeyManager.shared.unsubscribeFromGlobalEvents(id: id)
            eventMonitorId = nil
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

struct PopoverContainerView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        SearchViewSimple()
            .environment(\.locale, Locale(identifier: preferencesManager.language.rawValue))
            .environmentObject(ImageStore.shared)
    }
}
