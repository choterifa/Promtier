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
    
    private let tabs: [(title: LocalizedStringKey, icon: String)] = [
        (title: "appearance_tab", icon: "paintbrush.fill"),
        (title: "general_tab", icon: "gearshape.fill"),
        (title: "shortcuts_tab", icon: "keyboard.fill"),
        (title: "snippets_tab", icon: "text.quote"),
        (title: "data_tab", icon: "externaldrive.fill"),
        (title: "support_tab", icon: "questionmark.circle.fill")
    ]
    
    private var tabsContent: some View {
        HStack(spacing: 2) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index } }) {
                    HStack(spacing: 6) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 13 * preferences.fontSize.scale, weight: .semibold))
                        Text(tabs[index].title)
                            .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(
                        ZStack {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                            }
                        }
                    )
                    .foregroundColor(selectedTab == index ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings".localized(for: preferences.language))
                        .font(.system(size: 24 * preferences.fontSize.scale, weight: .bold))
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
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Selector de pestañas personalizado (Segmented Premium)
            // Selector de pestañas personalizado (Segmented Premium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    tabsContent
                    Spacer(minLength: 0)
                }
                .frame(minWidth: max(0, preferences.windowWidth - 64))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            
            Divider()
                .padding(.horizontal, 32)
            
            // Contenido de la pestaña
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if selectedTab == 3 && !preferences.isPremiumActive {
                        PremiumUpsellView(featureName: "snippets_tab".localized(for: preferences.language))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        switch selectedTab {
                        case 0: AppearanceTab()
                        case 1: BehaviorTab()
                        case 2: ShortcutsTab()
                        case 3: SnippetsManagerTab()
                        case 4: DataTab(
                            showingResetAlert: $showingResetAlert,
                            onClose: onClose
                        )
                        case 5: SupportTab()
                        default: EmptyView()
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
            }
        }
        .onAppear {
            // Inicializar estados temporales en el manager para el HUD
            preferences.previewWidth = preferences.windowWidth
            preferences.previewHeight = preferences.windowHeight
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // Decoración sutil de fondo
                Circle()
                    .fill(Color.blue.opacity(0.03))
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(x: 200, y: -200)
            }
        )
        .sheet(isPresented: $showingExportSheet) { ExportView() }
        .sheet(isPresented: $showingImportSheet) { ImportView() }
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
}

// MARK: - Componentes de Estilo

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 14 * preferences.fontSize.scale, weight: .bold))
                Text(title)
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .textCase(.uppercase)
            }
            
            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let icon: String?
    let iconColor: Color?
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(_ label: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, icon: String? = nil, iconColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18 * preferences.fontSize.scale))
                    .foregroundColor(iconColor ?? .blue)
                    .frame(width: 28 * preferences.fontSize.scale)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14 * preferences.fontSize.scale, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12 * preferences.fontSize.scale))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity) // Forzar que ocupe todo el ancho
        .contentShape(Rectangle())
    }
}

// MARK: - Tabs Rediseñados

struct AppearanceTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "appearance", icon: "display") {
                SettingsRow("language", subtitle: "language_subtitle") {
                    Picker("", selection: $preferences.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("appearance", subtitle: "appearance_subtitle") {
                    Picker("", selection: $preferences.appearance) {
                        Text("light").tag(AppAppearance.light)
                        Text("dark").tag(AppAppearance.dark)
                        Text("system").tag(AppAppearance.system)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("font_size", subtitle: "font_size_subtitle") {
                    Picker("", selection: $preferences.fontSize) {
                        Text("S").tag(FontSize.small)
                        Text("M").tag(FontSize.medium)
                        Text("L").tag(FontSize.large)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("preview_priority", subtitle: "preview_priority_subtitle") {
                    Picker("", selection: $preferences.previewImagesFirst) {
                        Text("images_first").tag(true)
                        Text("text_first").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                
                if preferences.isPremiumActive {
                    Divider().padding(.leading, 20)
                    
                    SettingsRow("visual_effects", subtitle: "visual_effects_subtitle") {
                        Toggle("", isOn: $preferences.visualEffectsEnabled)
                            .toggleStyle(.switch)
                    }
                }
            }
            
            SettingsSection(title: "window", icon: "macwindow.badge.plus") {
                SettingsRow("width", subtitle: "\(Int(preferences.previewWidth))px") {
                    Slider(value: $preferences.previewWidth, in: 500...900, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowWidth = preferences.previewWidth
                        }
                    })
                    .frame(width: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("height", subtitle: "\(Int(preferences.previewHeight))px") {
                    Slider(value: $preferences.previewHeight, in: 450...750, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowHeight = preferences.previewHeight
                        }
                    })
                    .frame(width: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("reset_size", subtitle: "reset_size_subtitle") {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            preferences.previewWidth  = 690
                            preferences.previewHeight = 540
                            preferences.windowWidth   = 690
                            preferences.windowHeight  = 540
                        }
                    }) {
                        Label("reset", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


struct BehaviorTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @ObservedObject private var shortcutManager = ShortcutManager.shared
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "interaction", icon: "hand.tap.fill") {
                SettingsRow("sounds", subtitle: "sounds_subtitle") {
                    Toggle("", isOn: $preferences.soundEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("ghost_tips", subtitle: "ghost_tips_subtitle", icon: "sparkles", iconColor: .blue) {
                    Toggle("", isOn: $preferences.ghostTipsEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)

                SettingsRow("disable_image_animations", subtitle: "disable_image_animations_subtitle", icon: "video.slash.fill", iconColor: .purple) {
                    Toggle("", isOn: $preferences.disableImageAnimations)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("close_on_copy", subtitle: "close_on_copy_subtitle", icon: "xmark.square.fill", iconColor: .red) {
                    Toggle("", isOn: $preferences.closeOnCopy)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("auto_paste", subtitle: "auto_paste_subtitle", icon: "wand.and.stars", iconColor: .orange) {
                    Toggle("", isOn: $preferences.autoPaste)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("accessibility", subtitle: shortcutManager.isAccessibilityGranted ? "accessibility_granted" : "accessibility_required", icon: "lock.shield", iconColor: shortcutManager.isAccessibilityGranted ? .green : .orange) {
                    Button(shortcutManager.isAccessibilityGranted ? "accessibility_verified" : "accessibility_configure") {
                        shortcutManager.checkAccessibilityPermissions(forceDialog: true, ignoreSuppression: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(shortcutManager.isAccessibilityGranted)
                }
            }
            
            SettingsSection(title: "haptic_feedback", icon: "hand.tap.fill") {
                SettingsRow("haptic_feedback", subtitle: "haptic_feedback_subtitle") {
                    Toggle("", isOn: $preferences.hapticFeedbackEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("test_vibration", subtitle: "test_vibration_subtitle") {
                    HStack(spacing: 12) {
                        Button("haptic_light") {
                            HapticService.shared.playLight()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("haptic_medium") {
                            HapticService.shared.playAlignment()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("haptic_strong") {
                            HapticService.shared.playStrong()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .controlSize(.small)
                }
                
                Divider().padding(.leading, 20)
                
                Text("haptic_note")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            
            SettingsSection(title: "intelligence", icon: "sparkles") {
                SettingsRow("apple_intelligence", subtitle: "apple_intelligence_subtitle") {
                    Toggle("", isOn: $preferences.appleIntelligenceEnabled)
                        .toggleStyle(.switch)
                }
            }
            
            SettingsSection(title: "system", icon: "macwindow") {
                SettingsRow("launch_at_login", subtitle: "launch_at_login_subtitle") {
                    Toggle("", isOn: $preferences.launchAtLogin)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("updates", subtitle: "updates_subtitle", icon: "arrow.clockwise.circle", iconColor: .blue) {
                    Button("check_now") {
                        UpdateProvider.shared.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            SettingsSection(title: "premium", icon: "crown.fill") {
                SettingsRow("activate_premium", subtitle: "activate_premium_subtitle", icon: "sparkles", iconColor: .purple) {
                    Toggle("", isOn: $preferences.isPremiumActive)
                        .toggleStyle(.switch)
                }
            }
        }
    }
}


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
                        ShortcutRecorderView()
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
                ShortcutRow(label: "copy", shortcut: "⌘C")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "edit", shortcut: "↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "toggle_sidebar",    shortcut: "⌘B")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "new_prompt",               shortcut: "⌘N")
            }
            
            // Editor de prompt
            SettingsSection(title: "prompt_editor", icon: "square.and.pencil") {
                ShortcutRow(label: "save_prompt",                  shortcut: "⌘S")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "open_snippets",        shortcut: "/")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "snippet_up",          shortcut: "↑")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "snippet_down",           shortcut: "↓")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "insert_snippet", shortcut: "↩ / Esc")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "insert_variable",               shortcut: "⌥V")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "zen_mode",    shortcut: "⌘⇧Z")
            }
            
            // Variables
            SettingsSection(title: "fill_variables", icon: "curlybraces") {
                ShortcutRow(label: "next_field",  shortcut: "↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "copy_final_prompt",         shortcut: "⌘↩")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "cancel_close",     shortcut: "Esc")
            }
            
            // Ventana
            SettingsSection(title: "window", icon: "macwindow") {
                ShortcutRow(label: "toggle_promtier",  shortcut: "Atajo Global")
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
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv  = "CSV"
        var id: String { rawValue }
        var icon: String { self == .json ? "doc.text" : "tablecells" }
        var subtitle: String {
            self == .json
                ? "export_json_subtitle"
                : "export_csv_subtitle"
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
                    .frame(width: 130)
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
                    Toggle("", isOn: $preferences.icloudSyncEnabled)
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
        }
    }
    
    /// Lógica de exportación nativa — soporta JSON y CSV
    private func exportData(as format: ExportFormat) {
        let data: Data?
        let filename: String
        let contentType: UTType
        let timestamp = Int(Date().timeIntervalSince1970)
        
        switch format {
        case .json:
            data = promptService.exportAllPromptsAsJSON()
            filename = "promtier_backup_\(timestamp).json"
            contentType = .json
        case .csv:
            data = promptService.exportAllPromptsAsCSV()
            filename = "promtier_prompts_\(timestamp).csv"
            contentType = .commaSeparatedText
        }
        
        guard let exportData = data else { return }
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [contentType]
            savePanel.nameFieldStringValue = filename
            savePanel.title = "import_library".localized(for: preferences.language)
            
            NSApp.activate(ignoringOtherApps: true)
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try exportData.write(to: url)
                        print("✅ Exportado: \(url.path)")
                    } catch {
                        print("❌ Error guardando: \(error)")
                    }
                }
            }
        }
    }
    
    /// Lógica de importación nativa
    private func importData() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [.json]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.title = "import_library".localized(for: preferences.language)
            
            NSApp.activate(ignoringOtherApps: true)
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    do {
                        let data = try Data(contentsOf: url)
                        let result = self.promptService.importPromptsFromData(data)
                        
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
        VStack(spacing: 32) {
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
            .padding(.top, 16)
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
