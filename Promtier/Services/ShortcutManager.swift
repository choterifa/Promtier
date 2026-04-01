//
//  ShortcutManager.swift
//  Promtier
//
//  SERVICIO: Gestión de atajos de teclado globales (simplificado)
//  Created by Carlos on 15/03/26.
//

import AppKit
import Combine
import Carbon

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var isEnabled = true
    @Published var isAccessibilityGranted = false
    
    // Eliminamos la dependencia circular
    // private let menuBarManager = MenuBarManager.shared
    
    // Atajos configurados (simplificado sin Carbon)
    private struct Shortcut {
        let name: String
        let keyCombination: String
        let action: () -> Void
        
        init(name: String, keyCombination: String, action: @escaping () -> Void) {
            self.name = name
            self.keyCombination = keyCombination
            self.action = action
        }
    }
    
    private let shortcuts: [Shortcut] = [
        Shortcut(name: "Toggle Popover", keyCombination: "⌘⇧P", action: {
            // Acceso directo sin dependencia circular
            MenuBarManager.shared.togglePopover()
        }),
        
        Shortcut(name: "Show Popover", keyCombination: "⌘P", action: {
            MenuBarManager.shared.showPopover()
        }),
        
        Shortcut(name: "Close Popover", keyCombination: "⌘⌥P", action: {
            MenuBarManager.shared.closePopover()
        }),
    ]
    
    private var hotKeyRef: EventHotKeyRef?
    private var omniHotKeyRef: EventHotKeyRef?
    private var fastAddHotKeyRef: EventHotKeyRef?
    private var categoryHotKeyRef: EventHotKeyRef?
    private var newPromptHotKeyRef: EventHotKeyRef?
    private var aiDraftHotKeyRef: EventHotKeyRef?
    private var promptHotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var promptHotkeyMap: [UInt32: UUID] = [:]
    private var nextHotKeyId: UInt32 = 2
    
    private var localMonitor: Any?
    private var permissionTimer: Timer?
    private static var isHandlerInstalled = false
    private var hasLoggedInitialAccessibilityState = false
    
    private init() {
        print("✅ ShortcutManager inicializado")
        checkAccessibilityPermissions()
        setupMonitors()
        setupCarbonHotKey()
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
            let keyCode = UInt32(prefs.hotkeyCode)
            var carbonModifiers: UInt32 = 0
            let flags = NSEvent.ModifierFlags(rawValue: UInt(prefs.hotkeyModifiers))
            if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            
            let hotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 1) // 'PROM'
            _ = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        }
        
        // 2. HotKey Omni-Search: configurable en ajustes
        if prefs.omniHotkeyCode != -1 {
            let omniKeyCode = UInt32(prefs.omniHotkeyCode)
            var omniCarbonMods: UInt32 = 0
            let omniFlags = NSEvent.ModifierFlags(rawValue: UInt(prefs.omniHotkeyModifiers))
            if omniFlags.contains(.command) { omniCarbonMods |= UInt32(cmdKey) }
            if omniFlags.contains(.shift) { omniCarbonMods |= UInt32(shiftKey) }
            if omniFlags.contains(.option) { omniCarbonMods |= UInt32(optionKey) }
            if omniFlags.contains(.control) { omniCarbonMods |= UInt32(controlKey) }
            
            let omniHotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 100)
            _ = RegisterEventHotKey(omniKeyCode, omniCarbonMods, omniHotKeyID, GetApplicationEventTarget(), 0, &omniHotKeyRef)
        }
        
        // 3. HotKey Fast Add: personalizable
        if prefs.fastAddHotkeyCode != -1 {
            let fastAddKeyCode = UInt32(prefs.fastAddHotkeyCode)
            var fastAddCarbonMods: UInt32 = 0
            let fastAddFlags = NSEvent.ModifierFlags(rawValue: UInt(prefs.fastAddHotkeyModifiers))
            if fastAddFlags.contains(.command) { fastAddCarbonMods |= UInt32(cmdKey) }
            if fastAddFlags.contains(.shift) { fastAddCarbonMods |= UInt32(shiftKey) }
            if fastAddFlags.contains(.option) { fastAddCarbonMods |= UInt32(optionKey) }
            if fastAddFlags.contains(.control) { fastAddCarbonMods |= UInt32(controlKey) }
            
            let fastAddHotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 101)
            _ = RegisterEventHotKey(fastAddKeyCode, fastAddCarbonMods, fastAddHotKeyID, GetApplicationEventTarget(), 0, &fastAddHotKeyRef)
        }
        
        // 4. HotKey Create Category: personalizable
        if prefs.categoryHotkeyCode != -1 {
            let catKeyCode = UInt32(prefs.categoryHotkeyCode)
            var catCarbonMods: UInt32 = 0
            let catFlags = NSEvent.ModifierFlags(rawValue: UInt(prefs.categoryHotkeyModifiers))
            if catFlags.contains(.command) { catCarbonMods |= UInt32(cmdKey) }
            if catFlags.contains(.shift) { catCarbonMods |= UInt32(shiftKey) }
            if catFlags.contains(.option) { catCarbonMods |= UInt32(optionKey) }
            if catFlags.contains(.control) { catCarbonMods |= UInt32(controlKey) }
            
            let catHotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 102)
            _ = RegisterEventHotKey(catKeyCode, catCarbonMods, catHotKeyID, GetApplicationEventTarget(), 0, &categoryHotKeyRef)
        }
        
        // 5. HotKey New Prompt: global configurable (Cmd+Shift+A default)
        if prefs.newPromptHotkeyCode != -1 {
            let npKeyCode = UInt32(prefs.newPromptHotkeyCode)
            var npCarbonMods: UInt32 = 0
            let npFlags = NSEvent.ModifierFlags(rawValue: UInt(prefs.newPromptHotkeyModifiers))
            if npFlags.contains(.command) { npCarbonMods |= UInt32(cmdKey) }
            if npFlags.contains(.shift) { npCarbonMods |= UInt32(shiftKey) }
            if npFlags.contains(.option) { npCarbonMods |= UInt32(optionKey) }
            if npFlags.contains(.control) { npCarbonMods |= UInt32(controlKey) }
            
            let npHotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 103)
            _ = RegisterEventHotKey(npKeyCode, npCarbonMods, npHotKeyID, GetApplicationEventTarget(), 0, &newPromptHotKeyRef)
        }
        
        // 6. HotKey AI Draft: global configurable (Cmd+Shift+D default)
        if prefs.aiDraftHotkeyCode != -1 {
            let aidKeyCode = UInt32(prefs.aiDraftHotkeyCode)
            var aidCarbonMods: UInt32 = 0
            let aidFlags = NSEvent.ModifierFlags(rawValue: UInt(prefs.aiDraftHotkeyModifiers))
            if aidFlags.contains(.command) { aidCarbonMods |= UInt32(cmdKey) }
            if aidFlags.contains(.shift) { aidCarbonMods |= UInt32(shiftKey) }
            if aidFlags.contains(.option) { aidCarbonMods |= UInt32(optionKey) }
            if aidFlags.contains(.control) { aidCarbonMods |= UInt32(controlKey) }
            
            let aidHotKeyID = EventHotKeyID(signature: OSType(1347571781), id: 104)
            _ = RegisterEventHotKey(aidKeyCode, aidCarbonMods, aidHotKeyID, GetApplicationEventTarget(), 0, &aiDraftHotKeyRef)
        }
        
        // Instalar el manejador de eventos una sola vez globalmente
        if !ShortcutManager.isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            
            InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                var hkCom = EventHotKeyID()
                let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
                
                if status == noErr {
                    ShortcutManager.handleGlobalHotKey(id: hkCom.id)
                }
                return noErr
            }, 1, &eventType, nil, nil)
            
            ShortcutManager.isHandlerInstalled = true
        }
        print("💎 Carbon HotKeys registrados (Principal: \(prefs.hotkeyCode), Omni: \(prefs.omniHotkeyCode))")
    }
    
    // Método para registrar hotkeys dinámicos de prompts
    func registerPromptHotkeys(prompts: [Prompt]) {
        // Limpiar anteriores
        for (_, ref) in promptHotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        promptHotKeyRefs.removeAll()
        promptHotkeyMap.removeAll()
        nextHotKeyId = 2 // 1 está reservado para Toggle Popover
        
        for prompt in prompts {
            guard let shortcutStr = prompt.customShortcut else { continue }
            let parts = shortcutStr.split(separator: ":")
            guard parts.count == 2,
                  let kc = UInt32(parts[0]),
                  let mods = UInt(parts[1]) else { continue }
            
            var carbonModifiers: UInt32 = 0
            let flags = NSEvent.ModifierFlags(rawValue: mods)
            if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
            
            let hotKeyId = nextHotKeyId
            nextHotKeyId += 1
            
            let hotKeyIDStruct = EventHotKeyID(signature: OSType(1347571781), id: hotKeyId)
            var registration: EventHotKeyRef?
            
            let status = RegisterEventHotKey(kc, carbonModifiers, hotKeyIDStruct, GetApplicationEventTarget(), 0, &registration)
            
            if status == noErr, let ref = registration {
                promptHotKeyRefs[hotKeyId] = ref
                promptHotkeyMap[hotKeyId] = prompt.id
            }
        }
    }
    
    // Método estático para el handler de Carbon
    static func handleGlobalHotKey(id: UInt32) {
        DispatchQueue.main.async {
            shared.handleCarbonHotKey(id: id)
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
                // If both are visible and have content, just bring the secondary to front
                secondary.bringToFront()
            }
        } else if id == 102 {
            MenuBarManager.shared.folderToEdit = nil
            MenuBarManager.shared.showWithState(.folderManager)
        } else if id == 103 {
            MenuBarManager.shared.showWithState(.newPrompt)
        } else if id == 104 {
            // Grab selection automatically for "Magic" experience
            let pasteboard = NSPasteboard.general
            let oldChangeCount = pasteboard.changeCount
            
            // CoreGraphics event simulation for Cmd+C
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
            
            // Wait for pasteboard update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let selection = (pasteboard.changeCount != oldChangeCount) ? pasteboard.string(forType: .string) : nil
                FloatingAIDraftManager.shared.show(content: selection ?? "", autoImprove: selection != nil)
            }
        } else if let promptId = promptHotkeyMap[id] {
            // Notificar a PromptService para copiar
            NotificationCenter.default.post(name: NSNotification.Name("PromtierCustomShortcutPressed"), object: promptId)
        }
    }
    
    // MARK: - Accesibilidad
    
    private var lastPermissionCheck: Date = Date.distantPast
    
    @discardableResult
    func checkAccessibilityPermissions(forceDialog: Bool = false) -> Bool {
        // Evitar spam al sistema: si no es forzado, solo comprobar cada 60 segundos
        if !forceDialog && Date().timeIntervalSince(lastPermissionCheck) < 60 {
            return isAccessibilityGranted
        }
        
        lastPermissionCheck = Date()
        
        // 1. Comprobación silenciosa para actualizar el estado interno
        let silentOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(silentOptions)
        
        // Actualizar propiedad publicada para la UI
        DispatchQueue.main.async {
            if self.isAccessibilityGranted != isTrusted {
                self.isAccessibilityGranted = isTrusted
            }
        }

        if !hasLoggedInitialAccessibilityState {
            print("🔍 [ShortcutManager] Comprobando accesibilidad. Estado: \(isTrusted ? "CONCEDIDO" : "DENEGADO")")
            hasLoggedInitialAccessibilityState = true
        }
        
        // 2. Si no es confiable y se solicita diálogo
        if !isTrusted && forceDialog {
            print("🏛️ Invocando diálogo nativo de accesibilidad de macOS")
            let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(promptOptions)
        }
        
        return isTrusted
    }
    
    // MARK: - Monitores de Eventos
    
    private func setupMonitors() {
        // Monitor local (cuando la app está en foco)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
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
    
    func getShortcutInfo() -> [(name: String, key: String, modifiers: String)] { [] }
}
