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
    
    private let tabs = [
        (title: "Apariencia", icon: "paintbrush.fill"),
        (title: "General", icon: "gearshape.fill"),
        (title: "Atajos", icon: "keyboard.fill"),
        (title: "Snippets", icon: "text.quote"),
        (title: "Datos", icon: "externaldrive.fill")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuración")
                        .font(.system(size: 24 * preferences.fontSize.scale, weight: .bold))
                    Text("Personaliza tu experiencia en Promtier")
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
                .help("Cerrar (Esc)")
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Selector de pestañas personalizado (Segmented Premium)
            HStack(spacing: 4) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = index } }) {
                        HStack(spacing: 8) {
                            Image(systemName: tabs[index].icon)
                                .font(.system(size: 14 * preferences.fontSize.scale, weight: .semibold))
                            Text(tabs[index].title)
                                .font(.system(size: 13 * preferences.fontSize.scale, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle()) // Asegurar que todo el padding es clickable
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
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            
            Divider()
                .padding(.horizontal, 32)
            
            // Contenido de la pestaña
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    switch selectedTab {
                    case 0: AppearanceTab()
                    case 1: BehaviorTab()
                    case 2: ShortcutsTab()
                    case 3: SnippetsManagerTab()
                    case 4: DataTab(
                        showingResetAlert: $showingResetAlert,
                        onClose: onClose
                    )
                    default: EmptyView()
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
        .alert("Restablecer Todo", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer a Fábrica", role: .destructive) {
                preferences.resetToDefaults()
                promptService.resetAllData()
            }
        } message: {
            Text("Se perderán permanentemente todos tus ajustes y prompts de la biblioteca.")
        }
    }
}

// MARK: - Componentes de Estilo

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
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
                Text(title.uppercased())
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
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
    let label: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(_ label: String, subtitle: String? = nil, icon: String? = nil, iconColor: Color? = nil, @ViewBuilder content: () -> Content) {
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
            SettingsSection(title: "Interfaz", icon: "display") {
                SettingsRow("Apariencia", subtitle: "Selecciona el modo visual de la app") {
                    Picker("", selection: $preferences.appearance) {
                        Text("Claro").tag(AppAppearance.light)
                        Text("Oscuro").tag(AppAppearance.dark)
                        Text("Sistema").tag(AppAppearance.system)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Tamaño de Fuente", subtitle: "Ajusta el texto de tus prompts") {
                    Picker("", selection: $preferences.fontSize) {
                        Text("S").tag(FontSize.small)
                        Text("M").tag(FontSize.medium)
                        Text("L").tag(FontSize.large)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                if preferences.isPremiumActive {
                    Divider().padding(.leading, 20)
                    
                    SettingsRow("Vibras Visuales ✨", subtitle: "Efectos especiales al copiar y guardar prompts") {
                        Toggle("", isOn: $preferences.visualEffectsEnabled)
                            .toggleStyle(.switch)
                    }
                }
            }
            
            SettingsSection(title: "Ventana", icon: "macwindow.badge.plus") {
                SettingsRow("Ancho", subtitle: "\(Int(preferences.previewWidth))px") {
                    Slider(value: $preferences.previewWidth, in: 450...1000, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowWidth = preferences.previewWidth
                        }
                    })
                    .frame(width: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Alto", subtitle: "\(Int(preferences.previewHeight))px") {
                    Slider(value: $preferences.previewHeight, in: 400...900, step: 10, onEditingChanged: { editing in
                        preferences.isResizingVisible = editing
                        if !editing {
                            preferences.windowHeight = preferences.previewHeight
                        }
                    })
                    .frame(width: 150)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Restablecer tamaño", subtitle: "Volver al tamaño por defecto (690 × 540)") {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            preferences.previewWidth  = 690
                            preferences.previewHeight = 540
                            preferences.windowWidth   = 690
                            preferences.windowHeight  = 540
                        }
                    }) {
                        Label("Resetear", systemImage: "arrow.counterclockwise")
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
            SettingsSection(title: "Interacción", icon: "hand.tap.fill") {
                SettingsRow("Sonidos", subtitle: "Feedback auditivo al copiar") {
                    Toggle("", isOn: $preferences.soundEnabled)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Cerrar al copiar", subtitle: "Cierra la ventana automáticamente", icon: "xmark.square.fill", iconColor: .red) {
                    Toggle("", isOn: $preferences.closeOnCopy)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Pegado Instantáneo", subtitle: "Pega automáticamente el prompt en la aplicación activa después de copiarlo.", icon: "wand.and.stars", iconColor: .orange) {
                    Toggle("", isOn: $preferences.autoPaste)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Accesibilidad", subtitle: shortcutManager.isAccessibilityGranted ? "Permisos concedidos ✅" : "Permisos requeridos ⚠️", icon: "lock.shield", iconColor: shortcutManager.isAccessibilityGranted ? .green : .orange) {
                    Button(shortcutManager.isAccessibilityGranted ? "Verificado" : "Configurar") {
                        shortcutManager.checkAccessibilityPermissions(forceDialog: true, ignoreSuppression: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(shortcutManager.isAccessibilityGranted)
                }
            }
            
            SettingsSection(title: "Sistema", icon: "macwindow") {
                SettingsRow("Inicio Automático", subtitle: "Abrir Promtier al iniciar sesión") {
                    Toggle("", isOn: $preferences.launchAtLogin)
                        .toggleStyle(.switch)
                }
                
                Divider().padding(.leading, 20)
                
                SettingsRow("Mostrar en el Dock", subtitle: "Icono visible en la barra de apps") {
                    Toggle("", isOn: $preferences.showInDock)
                        .toggleStyle(.switch)
                }
            }
            
            SettingsSection(title: "Promtier Premium 💎", icon: "crown.fill") {
                SettingsRow("Activar Funciones Premium", subtitle: "Simular estado Premium para pruebas del creador", icon: "sparkles", iconColor: .purple) {
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
            SettingsSection(title: "Atajo Global", icon: "command") {
                SettingsRow("Atajos Globales", subtitle: "Habilitar combinaciones en todo el sistema") {
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
            SettingsSection(title: "Navegación de Lista", icon: "list.bullet") {
                ShortcutRow(label: "Mover selección arriba",     shortcut: "↑")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Mover selección abajo",      shortcut: "↓")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Abrir Vista Previa",         shortcut: "Espacio")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Copiar prompt seleccionado", shortcut: "⌘C")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Editar prompt seleccionado", shortcut: "↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Mostrar/Ocultar Sidebar",    shortcut: "⌘B")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Nuevo Prompt",               shortcut: "⌘N")
            }
            
            // Editor de prompt
            SettingsSection(title: "Editor de Prompt", icon: "square.and.pencil") {
                ShortcutRow(label: "Guardar prompt",                  shortcut: "⌘S")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Apertura de Snippets (/)",        shortcut: "/")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Navegar snippet arriba",          shortcut: "↑")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Navegar snippet abajo",           shortcut: "↓")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Insertar snippet / Cerrar menú", shortcut: "↩ / Esc")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Insertar variable",               shortcut: "⌥V")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Modo Zen (pantalla completa)",    shortcut: "⌘⇧Z")
            }
            
            // Variables
            SettingsSection(title: "Rellenar Variables", icon: "curlybraces") {
                ShortcutRow(label: "Avanzar al siguiente campo",  shortcut: "↩ Enter")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Copiar prompt final",         shortcut: "⌘↩")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Cancelar / Cerrar panel",     shortcut: "Esc")
            }
            
            // Ventana
            SettingsSection(title: "Ventana", icon: "macwindow") {
                ShortcutRow(label: "Abrir / Cerrar Promtier",  shortcut: "Atajo Global")
                Divider().padding(.leading, 20)
                ShortcutRow(label: "Cerrar ventana",           shortcut: "Esc")
            }
        }
    }
}

private struct ShortcutRow: View {
    let label: String
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
                ? "Backup completo con carpetas (recomendado)"
                : "Solo prompts — compatible con Excel / Sheets"
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "Exportar", icon: "square.and.arrow.up") {
                // Selector de formato
                SettingsRow("Formato", subtitle: "Elige el formato de exportación") {
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
                    SettingsRow(exportFormat.subtitle,
                                subtitle: "Guardar archivo .\(exportFormat.rawValue.lowercased())",
                                icon: exportFormat.icon,
                                iconColor: .blue) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }.buttonStyle(.plain)
            }
            
            SettingsSection(title: "Importar", icon: "square.and.arrow.down") {
                Button(action: {
                    onClose()
                    menuBarManager.closePopover()
                    importData()
                }) {
                    SettingsRow("Importar Biblioteca", subtitle: "Carga desde un archivo JSON (formato Promtier)") {
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
            
            SettingsSection(title: "Cloud", icon: "icloud.fill") {
                SettingsRow("iCloud Sync", subtitle: "Sincroniza entre tus Macs") {
                    Toggle("", isOn: $preferences.icloudSyncEnabled)
                        .toggleStyle(.switch)
                }
            }
            
            Button(action: { showingResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restablecer todos los ajustes y datos")
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
            savePanel.title = "Exportar Biblioteca"
            
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
            openPanel.title = "Importar Biblioteca"
            
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
                Text("Exportar Datos")
                    .font(.system(size: 19, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cerrar") {
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
                    
                    Text("Selecciona qué datos deseas exportar:")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // TODO: Implementar opciones de exportación
                    Text("Opciones de exportación próximamente")
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
                Button("Cancelar") {
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
                
                Button("Exportar") {
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
                Text("Importar Datos")
                    .font(.system(size: 19, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cerrar") {
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
                    
                    Text("Arrastra un archivo JSON aquí o selecciónalo:")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // TODO: Implementar importación
                    Text("Importación de archivos próximamente")
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
                Button("Cancelar") {
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
                
                Button("Importar") {
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

#Preview {
    PreferencesView(onClose: {})
        .environmentObject(PreferencesManager.shared)
}
