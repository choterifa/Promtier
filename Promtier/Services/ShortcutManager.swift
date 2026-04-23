import AppKit
import Combine
import Carbon

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    
    @Published var isEnabled = true
    @Published var isAccessibilityGranted = false
    
    // Centralized monitors
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventSubscriptions: [UUID: (NSEvent) -> Void] = [:]
    
    // Carbon references
    private var hotKeyRef: EventHotKeyRef?
    private var omniHotKeyRef: EventHotKeyRef?
    private var fastAddHotKeyRef: EventHotKeyRef?
    private var categoryHotKeyRef: EventHotKeyRef?
    private var newPromptHotKeyRef: EventHotKeyRef?
    private var aiDraftHotKeyRef: EventHotKeyRef?
    private var promptHotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var promptHotkeyMap: [UInt32: UUID] = [:]
    private var nextHotKeyId: UInt32 = 2
    
    private var permissionTimer: Timer?
    private static var isHandlerInstalled = false
    private var hasLoggedInitialAccessibilityState = false
    
    private init() {
        print("✅ GlobalHotkeyManager inicializado")
        setupMonitors()
        setupCarbonHotKey()
    }
    
    // MARK: - Centralized NSEvent Monitor
    
    /// Registers a closure to be called when a global event (like mouse click) occurs. Returns an ID to unregister.
    func subscribeToGlobalEvents(handler: @escaping (NSEvent) -> Void) -> UUID {
        let id = UUID()
        eventSubscriptions[id] = handler
        return id
    }
    
    func unsubscribeFromGlobalEvents(id: UUID) {
        eventSubscriptions.removeValue(forKey: id)
    }
    
    private func setupMonitors() {
        // Monitor local (cuando la app está en foco)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
        
        // Monitor global centralizado (para clics fuera de la app, etc.)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self = self else { return }
            for handler in self.eventSubscriptions.values {
                handler(event)
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isEnabled else { return event }
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)
        
        // ⌘K (Búsqueda Rápida)
        if modifiers == .command && keyCode == 40 {
            MenuBarManager.shared.showWithState(.main)
            return nil
        }
        
        // ⌘N (Nuevo Prompt)
        if modifiers == .command && keyCode == 45 {
            MenuBarManager.shared.showWithState(.newPrompt)
            return nil
        }
        
        return event
    }
    
    // MARK: - Carbon HotKey (Detección Global Real)
    
    func setupCarbonHotKey() {
        // Limpiar registros previos
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = omniHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = fastAddHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = categoryHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = newPromptHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = aiDraftHotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
        omniHotKeyRef = nil
        fastAddHotKeyRef = nil
        categoryHotKeyRef = nil
        newPromptHotKeyRef = nil
        aiDraftHotKeyRef = nil
        
        let prefs = PreferencesManager.shared
        guard prefs.globalShortcutEnabled else { return }
        
        // 1. HotKey Principal: Toggle Popover
        if prefs.hotkeyCode != -1 {
            hotKeyRef = registerCarbonHotKey(keyCode: prefs.hotkeyCode, modifiers: prefs.hotkeyModifiers, id: 1)
        }
        if prefs.omniHotkeyCode != -1 {
            omniHotKeyRef = registerCarbonHotKey(keyCode: prefs.omniHotkeyCode, modifiers: prefs.omniHotkeyModifiers, id: 100)
        }
        if prefs.fastAddHotkeyCode != -1 {
            fastAddHotKeyRef = registerCarbonHotKey(keyCode: prefs.fastAddHotkeyCode, modifiers: prefs.fastAddHotkeyModifiers, id: 101)
        }
        if prefs.categoryHotkeyCode != -1 {
            categoryHotKeyRef = registerCarbonHotKey(keyCode: prefs.categoryHotkeyCode, modifiers: prefs.categoryHotkeyModifiers, id: 102)
        }
        if prefs.newPromptHotkeyCode != -1 {
            newPromptHotKeyRef = registerCarbonHotKey(keyCode: prefs.newPromptHotkeyCode, modifiers: prefs.newPromptHotkeyModifiers, id: 103)
        }
        if prefs.aiDraftHotkeyCode != -1 {
            aiDraftHotKeyRef = registerCarbonHotKey(keyCode: prefs.aiDraftHotkeyCode, modifiers: prefs.aiDraftHotkeyModifiers, id: 104)
        }
        
        // Instalar el manejador de eventos una sola vez globalmente
        if !Self.isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            
            InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                var hkCom = EventHotKeyID()
                let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
                
                if status == noErr {
                    Task { @MainActor in
                        GlobalHotkeyManager.shared.handleCarbonHotKey(id: hkCom.id)
                    }
                }
                return noErr
            }, 1, &eventType, nil, nil)
            
            Self.isHandlerInstalled = true
        }
        print("💎 Carbon HotKeys registrados dinámicamente")
    }
    
    private func registerCarbonHotKey(keyCode: Int, modifiers: Int, id: UInt32) -> EventHotKeyRef? {
        let kc = UInt32(keyCode)
        var carbonModifiers: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let hotKeyID = EventHotKeyID(signature: OSType(1347571781), id: id)
        var ref: EventHotKeyRef?
        _ = RegisterEventHotKey(kc, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        return ref
    }
    
    // Método para registrar hotkeys dinámicos de prompts
    func registerPromptHotkeys(prompts: [Prompt]) {
        for (_, ref) in promptHotKeyRefs { UnregisterEventHotKey(ref) }
        promptHotKeyRefs.removeAll()
        promptHotkeyMap.removeAll()
        nextHotKeyId = 2
        
        for prompt in prompts {
            guard let shortcutStr = prompt.customShortcut else { continue }
            let parts = shortcutStr.split(separator: ":")
            guard parts.count == 2,
                  let kc = Int(parts[0]),
                  let mods = Int(parts[1]) else { continue }
            
            let hotKeyId = nextHotKeyId
            nextHotKeyId += 1
            
            if let ref = registerCarbonHotKey(keyCode: kc, modifiers: mods, id: hotKeyId) {
                promptHotKeyRefs[hotKeyId] = ref
                promptHotkeyMap[hotKeyId] = prompt.id
            }
        }
    }
    
    func handleCarbonHotKey(id: UInt32) {
        if id == 1 {
            MenuBarManager.shared.togglePopover()
        } else if id == 100 {
            OmniSearchManager.shared.toggle()
        } else if id == 101 {
            let shared = FloatingZenManager.shared
            let secondary = FloatingZenManager.secondary
            if !shared.isVisible || !shared.hasUnsavedChanges {
                shared.show(title: "", promptDescription: "", content: "", promptId: nil, isEditing: false)
            } else if !secondary.isVisible || !secondary.hasUnsavedChanges {
                secondary.show(title: "", promptDescription: "", content: "", promptId: nil, isEditing: false)
            } else {
                secondary.bringToFront()
            }
        } else if id == 102 {
            MenuBarManager.shared.folderToEdit = nil
            MenuBarManager.shared.showWithState(.folderManager)
        } else if id == 103 {
            MenuBarManager.shared.showWithState(.newPrompt)
        } else if id == 104 {
            let pasteboard = NSPasteboard.general
            let oldChangeCount = pasteboard.changeCount
            let source = CGEventSource(stateID: .hidSystemState)
            let kVK_Command: CGKeyCode = 55
            let kVK_ANSI_C: CGKeyCode = 8
            
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
            let cDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_C, keyDown: true)
            cDown?.flags = .maskCommand
            let cUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_C, keyDown: false)
            cUp?.flags = .maskCommand
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)
            
            cmdDown?.post(tap: .cghidEventTap)
            cDown?.post(tap: .cghidEventTap)
            cUp?.post(tap: .cghidEventTap)
            cmdUp?.post(tap: .cghidEventTap)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let selection = (pasteboard.changeCount != oldChangeCount) ? pasteboard.string(forType: .string) : nil
                FloatingAIDraftManager.shared.show(content: selection ?? "", autoImprove: selection != nil)
            }
        } else if let promptId = promptHotkeyMap[id] {
            NotificationCenter.default.post(name: NSNotification.Name("PromtierCustomShortcutPressed"), object: promptId)
        }
    }
    
    // MARK: - Accesibilidad
    
    private var lastPermissionCheck: Date = Date.distantPast
    
    @discardableResult
    func checkAccessibilityPermissions(forceDialog: Bool = false) -> Bool {
        if !forceDialog && Date().timeIntervalSince(lastPermissionCheck) < 60 {
            return isAccessibilityGranted
        }
        
        lastPermissionCheck = Date()
        let silentOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(silentOptions)
        
        if self.isAccessibilityGranted != isTrusted {
            self.isAccessibilityGranted = isTrusted
        }

        if !hasLoggedInitialAccessibilityState {
            print("🔍 [GlobalHotkeyManager] Comprobando accesibilidad. Estado: \(isTrusted ? "CONCEDIDO" : "DENEGADO")")
            hasLoggedInitialAccessibilityState = true
        }
        
        if !isTrusted && forceDialog {
            let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(promptOptions)
        }
        
        return isTrusted
    }
    
    // MARK: - Control
    
    func enableShortcuts() {
        isEnabled = true
        setupCarbonHotKey()
    }
    
    func disableShortcuts() {
        isEnabled = false
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    func toggleShortcuts() {
        if isEnabled {
            disableShortcuts()
        } else {
            enableShortcuts()
        }
    }
}

typealias ShortcutManager = GlobalHotkeyManager
