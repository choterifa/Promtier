//
//  PreferencesView.swift
//  Promtier
//
//  VISTA: Configuración y preferencias de la aplicación
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreferencesView: View {
    var onClose: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @StateObject private var shortcutManager = ShortcutManager.shared
    
    @State private var selectedTab: Int = 0
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetAlert = false
    @State private var showingPremiumUpsell = false
    @State private var hoveredTab: Int? = nil
    
    private let tabs: [(title: LocalizedStringKey, icon: String)] = [
        (title: "appearance_tab", icon: "paintbrush.fill"),
        (title: "general_tab", icon: "gearshape.fill"),
        (title: "shortcuts_tab", icon: "keyboard.fill"),
        (title: "ai_tab", icon: "sparkles"),
        (title: "snippets_tab", icon: "text.quote"),
        (title: "data_tab", icon: "externaldrive.fill"),
        (title: "support_tab", icon: "questionmark.circle.fill"),
        (title: "trash_tab", icon: "trash.fill")
    ]
    
    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header del Sidebar
            Text("settings".localized(for: preferences.language).uppercased())
                .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1.2)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 32)
            
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { 
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { 
                        selectedTab = index 
                    } 
                    HapticService.shared.playImpact()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 14 * preferences.fontSize.scale, weight: .semibold))
                            .foregroundColor(selectedTab == index ? .white : .blue)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == index ? Color.white.opacity(0.15) : Color.blue.opacity(0.1))
                            )
                        
                        Text(tabs[index].title)
                            .font(.system(size: 13 * preferences.fontSize.scale, weight: selectedTab == index ? .bold : .medium))
                            .foregroundColor(selectedTab == index ? .white : .primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == index ? Color.blue : (hoveredTab == index ? Color.primary.opacity(0.06) : Color.clear))
                            .shadow(color: selectedTab == index ? Color.blue.opacity(0.3) : .clear, radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(.spring(response: 0.3)) { hoveredTab = h ? index : nil } }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
        .frame(width: 198)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor).opacity(0.98)
                Color.primary.opacity(0.02)
                
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        )
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Izquierdo
            sidebarContent
            
            // Contenido Derecho
            VStack(spacing: 0) {
                // Header del Contenido
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tabs[selectedTab].title)
                            .font(.system(size: 26 * preferences.fontSize.scale, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("settings_subtitle".localized(for: preferences.language))
                            .font(.system(size: 13 * preferences.fontSize.scale))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("\("close".localized(for: preferences.language)) (Esc)")
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 24)
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Scroll de opciones
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if selectedTab == 4 && !preferences.isPremiumActive {
                            premiumLockedSnippets
                        } else {
                            activeTabContent
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            preferences.previewWidth = preferences.windowWidth
            preferences.previewHeight = preferences.windowHeight
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingExportSheet) { ExportView() }
        .sheet(isPresented: $showingImportSheet) { ImportView() }
        .sheet(isPresented: $showingPremiumUpsell) { PremiumUpsellView(featureName: "snippets_tab".localized(for: preferences.language)) }
        .alert("reset_all".localized(for: preferences.language), isPresented: $showingResetAlert) {
            Button("cancel".localized(for: preferences.language), role: .cancel) { }
            Button("reset_factory".localized(for: preferences.language), role: .destructive) {
                preferences.resetToDefaults()
                promptService.resetAllData()
            }
        } message: {
            Text("reset_message".localized(for: preferences.language))
        }
    }
    
    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case 0: AppearanceTab()
        case 1: BehaviorTab()
        case 2: ShortcutsTab()
        case 3: AITab()
        case 4: SnippetsManagerTab()
        case 5: DataTab(showingResetAlert: $showingResetAlert, onClose: onClose)
        case 6: SupportTab()
        case 7: TrashView()
        default: EmptyView()
        }
    }
    
    private var premiumLockedSnippets: some View {
        ZStack {
            SnippetsManagerTab()
                .blur(radius: 6)
                .disabled(true)
                .allowsHitTesting(false)
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                
                Button(action: { showingPremiumUpsell = true }) {
                    Text("unlock_premium".localized(for: preferences.language))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(10)
                        .shadow(color: .purple.opacity(0.3), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Componentes de Glosario



// MARK: - Componentes de Estilo





// MARK: - Tabs Rediseñados









struct ShortcutsTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 32) {
            // Atajo global configurable
            SettingsSection(title: "shortcuts", icon: "command") {
                SettingsRow("global_shortcuts", subtitle: "global_shortcuts_subtitle") {
                    Toggle("", isOn: $preferences.globalShortcutEnabled)
                        .toggleStyle(.switch)
                }
                
                if preferences.globalShortcutEnabled {
                    Divider().padding(.leading, 20)
                    VStack(spacing: 12) {
                        ShortcutRecorderView(
                            label: "Atajo de apertura (App)",
                            hotkeyCode: $preferences.hotkeyCode,
                            hotkeyModifiers: $preferences.hotkeyModifiers,
                            defaultKeyCode: 35,
                            defaultModifiers: Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ShortcutRecorderView(
                            label: "Omni-Search (Spotlight)",
                            hotkeyCode: $preferences.omniHotkeyCode,
                            hotkeyModifiers: $preferences.omniHotkeyModifiers,
                            defaultKeyCode: 49,
                            defaultModifiers: Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ShortcutRecorderView(
                            label: "Fast Add (Floating Editor)",
                            hotkeyCode: $preferences.fastAddHotkeyCode,
                            hotkeyModifiers: $preferences.fastAddHotkeyModifiers,
                            defaultKeyCode: 3,
                            defaultModifiers: Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ShortcutRecorderView(
                            label: "Nueva Categoría (Folder Manager)",
                            hotkeyCode: $preferences.categoryHotkeyCode,
                            hotkeyModifiers: $preferences.categoryHotkeyModifiers,
                            defaultKeyCode: 45,
                            defaultModifiers: Int(NSEvent.ModifierFlags([.command, .option]).rawValue)
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ShortcutRecorderView(
                            label: "AI Quick Draft (Borrador)",
                            hotkeyCode: $preferences.aiDraftHotkeyCode,
                            hotkeyModifiers: $preferences.aiDraftHotkeyModifiers,
                            defaultKeyCode: 2,
                            defaultModifiers: Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                        )
                    }
                    .padding(20)
                }
            }
            
            // Lista principal
            SettingsSection(title: "list_navigation", icon: "list.bullet") {
                ShortcutRow(label: "move_up",     shortcut: "↑")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "move_down",      shortcut: "↓")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "preview",         shortcut: "Espacio")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "edit_from_preview", shortcut: "E")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "copy", shortcut: "⌘C")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "edit", shortcut: "Double Tap / ↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "toggle_sidebar",    shortcut: "⌘B")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "new_prompt",               shortcut: "⌘N")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "gallery_toggle",           shortcut: "⌘G")
            }

            SettingsSection(title: "omni_search_shortcuts", icon: "magnifyingglass") {
                ShortcutRow(label: "move_up", shortcut: "↑")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "move_down", shortcut: "↓")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "copy_and_close", shortcut: "↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "copy", shortcut: "⌘C")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "edit_prompt", shortcut: "⌘E")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "close_window", shortcut: "Esc")
            }
            
            // Editor de prompt
            SettingsSection(title: "prompt_editor", icon: "square.and.pencil") {
                ShortcutRow(label: "save_prompt",                  shortcut: "⌘S")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "open_snippets",        shortcut: "/")
                Divider().padding(.leading, 20)
                // ShortcutRow(label: "snippet_up",          shortcut: "↑")
                // Divider().padding(.leading, 20)
                // ShortcutRow(label: "snippet_down",           shortcut: "↓")
                // Divider().padding(.leading, 20)
                // ShortcutRow(label: "insert_snippet", shortcut: "↩ / Esc")
                // Divider().padding(.leading, 20)
                ShortcutRow(label: "insert_variable",               shortcut: "⌥V")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "focus_negative",               shortcut: "⌥N")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "focus_alternative",               shortcut: "⌥A")
            }
            
            // Variables
            // SettingsSection(title: "fill_variables", icon: "curlybraces") {
            //     ShortcutRow(label: "next_field",  shortcut: "↩ Enter")
            //     Divider().padding(.leading, 20)
            //     ShortcutRow(label: "copy_final_prompt",         shortcut: "⌘↩")
            //     Divider().padding(.leading, 20)
            //     ShortcutRow(label: "cancel_close",     shortcut: "Esc")
            // }
            
            // Ventana
            SettingsSection(title: "window", icon: "macwindow") {
                ShortcutRow(label: "toggle_promtier",  shortcut: "Atajo Global")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "global_shortcut_copy",  shortcut: "Atajo por Prompt")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "close_window",           shortcut: "Esc")
            }
        }
    }
}

private struct ShortcutRow: View {
    let label: LocalizedStringKey
    let shortcut: String
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13 * preferences.fontSize.scale))
                .foregroundColor(.primary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 12 * preferences.fontSize.scale, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}


struct DataTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var menuBarManager: MenuBarManager

    @Binding var showingResetAlert: Bool
    var onClose: () -> Void

    @State private var importStatus: String?
    @State private var exportFormat: ExportFormat = .json
    @State private var showingiCloudRestartAlert = false    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv  = "CSV"
        case zip  = "ZIP"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .json: return "doc.text"
            case .csv: return "tablecells"
            case .zip: return "doc.zipper"
            }
        }
        var subtitle: String {
            switch self {
            case .json: return "export_json_subtitle"
            case .csv: return "export_csv_subtitle"
            case .zip: return "export_zip_subtitle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "export", icon: "square.and.arrow.up") {
                // Selector de formato
                SettingsRow("format", subtitle: "export_format_subtitle") {
                    Picker("", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Text(fmt.rawValue).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                
                Divider().padding(.leading, 20)
                
                Button(action: {
                    onClose()
                    menuBarManager.closePopover()
                    exportData(as: exportFormat)
                }) {
                    SettingsRow(LocalizedStringKey(exportFormat.subtitle.localized(for: preferences.language)),
                                subtitle: LocalizedStringKey("save_as_file".localized(for: preferences.language)),
                                icon: exportFormat.icon,
                                iconColor: .blue) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }.buttonStyle(.plain)
            }
            
            SettingsSection(title: "import", icon: "square.and.arrow.down") {
                Button(action: {
                    onClose()
                    menuBarManager.closePopover()
                    importData()
                }) {
                    SettingsRow("import_library", subtitle: "import_subtitle") {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }.buttonStyle(.plain)
            }
            
            if let status = importStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, -16)
            }
            
            SettingsSection(title: "cloud", icon: "icloud.fill") {
                SettingsRow("icloud_sync", subtitle: "sync_macs") {
                    Toggle("", isOn: Binding(
                        get: { preferences.icloudSyncEnabled },
                        set: { newValue in
                            preferences.icloudSyncEnabled = newValue
                            Task {
                                await DataController.shared.toggleCloudSync(enabled: newValue)
                                HapticService.shared.playSuccess()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }
            }            
            Button(action: { showingResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("reset_all")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            }
            }
    /// Lógica de exportación nativa — soporta JSON y CSV
    private func exportData(as format: ExportFormat) {
        let timestamp = Int(Date().timeIntervalSince1970)

        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            switch format {
            case .json:
                savePanel.allowedContentTypes = [.json]
                savePanel.nameFieldStringValue = "promtier_backup_\(timestamp).json"
            case .csv:
                savePanel.allowedContentTypes = [.commaSeparatedText]
                savePanel.nameFieldStringValue = "promtier_prompts_\(timestamp).csv"
            case .zip:
                savePanel.allowedContentTypes = [.zip]
                savePanel.nameFieldStringValue = "promtier_backup_\(timestamp).zip"
            }
            savePanel.title = "import_library".localized(for: preferences.language)
            
            NSApp.activate(ignoringOtherApps: true)
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    switch format {
                    case .json:
                        guard let exportData = promptService.exportAllPromptsAsJSON() else { return }
                        do {
                            try exportData.write(to: url)
                            print("✅ Exportado: \(url.path)")
                        } catch {
                            print("❌ Error guardando: \(error)")
                        }
                    case .csv:
                        guard let exportData = promptService.exportAllPromptsAsCSV() else { return }
                        do {
                            try exportData.write(to: url)
                            print("✅ Exportado: \(url.path)")
                        } catch {
                            print("❌ Error guardando: \(error)")
                        }
                    case .zip:
                        DispatchQueue.global(qos: .utility).async {
                            let ok = promptService.exportBackupZip(to: url)
                            DispatchQueue.main.async {
                                withAnimation {
                                    self.importStatus = ok ? "✅ Backup ZIP exportado" : "❌ Error exportando ZIP"
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.importStatus = nil }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Lógica de importación nativa
    private func importData() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [.json, .zip]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.title = "import_library".localized(for: preferences.language)
            
            NSApp.activate(ignoringOtherApps: true)
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    do {
                        let result: (success: Int, failed: Int, foldersCreated: Int)
                        if url.pathExtension.lowercased() == "zip" {
                            result = self.promptService.importBackupZip(from: url)
                        } else {
                            let data = try Data(contentsOf: url)
                            result = self.promptService.importPromptsFromData(data)
                        }
                        
                        DispatchQueue.main.async {
                            withAnimation {
                                self.importStatus = "Prompts: \(result.success) | Carpetas: \(result.foldersCreated) | Omitidos: \(result.failed)"
                            }
                        }
                        
                        // Limpiar status después de 5 segundos
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.importStatus = nil
                        }
                    } catch {
                        print("❌ Error leyendo archivo: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Vistas de Exportación/Importación

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno
            HStack(spacing: 20) {
                Text("export_data")
                    .font(.system(size: 19, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("close") {
                    dismiss()
                }
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido principal
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("export_select_data")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // TODO: Implementar opciones de exportación
                    Text("coming_soon")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            
            // Footer moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            HStack(spacing: 12) {
                Button("cancel") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button("export") {
                    // TODO: Implementar exportación
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 770, height: 260)
    }
}

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno
            HStack(spacing: 20) {
                Text("import_data")
                    .font(.system(size: 19, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("close") {
                    dismiss()
                }
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Separador moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            // Contenido principal
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text("import_drag_drop")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // TODO: Implementar importación
                    Text("coming_soon")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            
            // Footer moderno
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)
            
            HStack(spacing: 12) {
                Button("cancel") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button("import") {
                    // TODO: Implementar importación
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 770, height: 260)
    }
}

// MARK: - Soporte y Legal

struct SupportTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsSection(title: "contact_help", icon: "envelope.fill") {
                Button(action: { openLink("mailto:soporte@promtier.app?subject=Consulta Promtier") }) {
                    SettingsRow("email_support", subtitle: "soporte@promtier.app", icon: "paperplane.fill", iconColor: .blue) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 60)
                
                Button(action: { openLink("mailto:soporte@promtier.app?subject=Reporte de Error - Promtier") }) {
                    SettingsRow("report_problem", subtitle: "report_details", icon: "ant.fill", iconColor: .orange) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            SettingsSection(title: "legal_privacy", icon: "doc.text.fill") {
                Button(action: { openLink("https://promtier.app/privacy") }) {
                    SettingsRow("privacy_policy", subtitle: "how_data_handled", icon: "hand.raised.fill", iconColor: .green) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 60)
                
                Button(action: { openLink("https://promtier.app/terms") }) {
                    SettingsRow("terms_service", subtitle: "app_conditions", icon: "list.bullet.rectangle.portrait.fill", iconColor: .purple) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Glosario de Iconos (Movido al final)
            SettingsSection(title: "icon_glossary", icon: "info.circle.fill") {
                VStack(spacing: 0) {
                    GlossaryRow(icon: "curlybraces", color: .blue, title: "glossary_variable_title", description: "glossary_variables_desc")
                    Divider().padding(.leading, 50)
                    GlossaryRow(icon: "cube.transparent.fill", color: .blue, title: "glossary_variable_indicator_title", description: "glossary_variable_indicator_desc")
                    Divider().padding(.leading, 50)
                    GlossaryRow(icon: "slash.circle.fill", color: .orange, title: "snippets_tab", description: "glossary_snippets_trigger_desc")
                    Divider().padding(.leading, 50)
                    GlossaryRow(icon: "clock.arrow.circlepath", color: .purple, title: "glossary_versions_indicator_title", description: "glossary_versions_indicator_desc")
                    Divider().padding(.leading, 50)
                    GlossaryRow(icon: "circle.fill", color: .red, title: "glossary_negative_dot_title", description: "glossary_negative_dot_desc")
                    Divider().padding(.leading, 50)
                    GlossaryRow(icon: "circle.fill", color: .green, title: "glossary_alternative_dot_title", description: "glossary_alternative_dot_desc")
                }
            }
            
            VStack(spacing: 8) {
                Image("AppIconPlaceholder") // O el logo de la app si está disponible
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
                    .opacity(0.8)
                
                Text("Promtier v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.system(size: 14, weight: .bold))
                
                Text("created_with_passion")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Button("visit_website") {
                    openLink("https://promtier.app")
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .padding(.top, 4)
            }
            .padding(.top, 4)
        }
    }
    
    private func openLink(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    PreferencesView(onClose: {})
        .environmentObject(PreferencesManager.shared)
}
