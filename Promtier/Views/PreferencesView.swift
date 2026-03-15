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
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con título y botón de cerrar
            HStack {
                Text("Preferencias")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cerrar") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // TabView sin NavigationView
            TabView {
                // Tab de Apariencia
                AppearanceTab()
                    .environmentObject(preferences)
                    .tabItem {
                        Label("Apariencia", systemImage: "paintbrush")
                    }
                
                // Tab de Comportamiento
                BehaviorTab()
                    .environmentObject(preferences)
                    .tabItem {
                        Label("Comportamiento", systemImage: "gear")
                    }
                
                // Tab de Atajos
                ShortcutsTab()
                    .environmentObject(preferences)
                    .tabItem {
                        Label("Atajos", systemImage: "keyboard")
                    }
                
                // Tab de Datos
                DataTab(
                    showingExportSheet: $showingExportSheet,
                    showingImportSheet: $showingImportSheet,
                    showingResetAlert: $showingResetAlert
                )
                .environmentObject(preferences)
                .tabItem {
                    Label("Datos", systemImage: "externaldrive")
                }
                
                // Tab de Avanzado
                AdvancedTab()
                    .environmentObject(preferences)
                    .tabItem {
                        Label("Avanzado", systemImage: "slider.horizontal.3")
                    }
            }
        }
        .frame(width: 800, height: 600) // Ventana más grande y espaciosa
        .sheet(isPresented: $showingExportSheet) {
            ExportView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportView()
        }
        .alert("Restablecer Configuración", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer", role: .destructive) {
                resetPreferences()
            }
        } message: {
            Text("Esta acción restablecerá todas las preferencias a sus valores por defecto. ¿Estás seguro?")
        }
    }
    
    private func resetPreferences() {
        preferences.resetToDefaults()
    }
}

// MARK: - Tabs de Preferencias

struct AppearanceTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        Form {
            Section(header: Text("Tema")) {
                Picker("Apariencia", selection: $preferences.appearance) {
                    Text("Claro").tag(AppAppearance.light)
                    Text("Oscuro").tag(AppAppearance.dark)
                    Text("Automático").tag(AppAppearance.system)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Tipografía")) {
                Picker("Tamaño de fuente", selection: $preferences.fontSize) {
                    Text("Pequeña").tag(FontSize.small)
                    Text("Mediana").tag(FontSize.medium)
                    Text("Grande").tag(FontSize.large)
                }
                
                Text("El tamaño de fuente afecta a toda la interfaz de la aplicación.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Colores")) {
                Toggle("Usar colores de acento del sistema", isOn: $preferences.useAccentColor)
                
                if !preferences.useAccentColor {
                    ColorPicker("Color de acento", selection: $preferences.accentColor)
                }
            }
        }
        .padding()
    }
}

struct BehaviorTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        Form {
            Section(header: Text("Interacción")) {
                Toggle("Efectos hápticos", isOn: $preferences.hapticFeedback)
                Toggle("Sonidos del sistema", isOn: $preferences.soundEnabled)
                Toggle("Cerrar al hacer clic fuera", isOn: $preferences.closeOnOutsideClick)
            }
            
            Section(header: Text("Notificaciones")) {
                Toggle("Mostrar notificaciones de copia", isOn: $preferences.showCopyNotifications)
                Toggle("Notificaciones de uso", isOn: $preferences.showUsageNotifications)
            }
            
            Section(header: Text ("Inicio")) {
                Toggle("Iniciar automáticamente al encender el Mac", isOn: $preferences.launchAtLogin)
                Toggle("Mostrar en el Dock", isOn: $preferences.showInDock)
            }
        }
        .padding()
    }
}

struct ShortcutsTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        Form {
            Section(header: Text("Atajos Globales")) {
                Toggle("Habilitar atajos globales", isOn: $preferences.globalShortcutEnabled)
                
                if preferences.globalShortcutEnabled {
                    HStack {
                        Text("Mostrar/Ocultar:")
                        Spacer()
                        Text("⌘⇧P")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Búsqueda rápida:")
                        Spacer()
                        Text("⌘K")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Nuevo prompt:")
                        Spacer()
                        Text("⌘N")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Atajos en la App")) {
                HStack {
                    Text("Copiar prompt:")
                    Spacer()
                    Text("⌘C")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Editar prompt:")
                    Spacer()
                    Text("⌘E")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Eliminar prompt:")
                    Spacer()
                    Text("⌘⌫")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct DataTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Binding var showingExportSheet: Bool
    @Binding var showingImportSheet: Bool
    @Binding var showingResetAlert: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Exportación/Importación")) {
                Button("Exportar datos...") {
                    showingExportSheet = true
                }
                
                Button("Importar datos...") {
                    showingImportSheet = true
                }
            }
            
            Section(header: Text("Sincronización")) {
                Toggle("Sincronizar con iCloud", isOn: $preferences.icloudSyncEnabled)
                
                if preferences.icloudSyncEnabled {
                    Text("Los datos se sincronizarán automáticamente entre tus dispositivos.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Restablecimiento")) {
                Button("Restablecer configuración", role: .destructive) {
                    showingResetAlert = true
                }
            }
        }
        .padding()
    }
}

struct AdvancedTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        Form {
            Section(header: Text("Rendimiento")) {
                Toggle("Optimización de memoria", isOn: $preferences.memoryOptimization)
                Toggle("Caché de búsqueda", isOn: $preferences.searchCache)
            }
            
            Section(header: Text("Depuración")) {
                Toggle("Modo desarrollador", isOn: $preferences.developerMode)
                
                if preferences.developerMode {
                    Text("El modo desarrollador muestra información adicional para depuración.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Privacidad")) {
                Toggle("Recopilar datos anónimos de uso", isOn: $preferences.analyticsEnabled)
                
                Toggle("Enviar informes de errores", isOn: $preferences.errorReporting)
            }
        }
        .padding()
    }
}

// MARK: - Vistas de Exportación/Importación

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Exportar Datos")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Selecciona qué datos deseas exportar:")
                .font(.body)
                .foregroundColor(.secondary)
            
            // TODO: Implementar opciones de exportación
            
            Spacer()
            
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Exportar") {
                    // TODO: Implementar exportación
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Importar Datos")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Arrastra un archivo JSON aquí o selecciónalo:")
                .font(.body)
                .foregroundColor(.secondary)
            
            // TODO: Implementar importación
            
            Spacer()
            
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Importar") {
                    // TODO: Implementar importación
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    PreferencesView()
        .environmentObject(PreferencesManager.shared)
}
