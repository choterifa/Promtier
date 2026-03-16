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
    
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header moderno con título y botón de cerrar
            HStack(spacing: 20) {
                Text("Preferencias")
                    .font(.system(size: 19, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cerrar") {
                    onClose()
                }
                .keyboardShortcut(.escape)
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
            
            // TabView moderno sin NavigationView
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
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
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Tema
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tema")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        Picker("Apariencia", selection: $preferences.appearance) {
                            Text("Claro").tag(AppAppearance.light)
                            Text("Oscuro").tag(AppAppearance.dark)
                            Text("Automático").tag(AppAppearance.system)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .font(.system(size: 16))
                    }
                }
                
                // Sección de Tipografía
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tipografía")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        Picker("Tamaño de fuente", selection: $preferences.fontSize) {
                            Text("Pequeña").tag(FontSize.small)
                            Text("Mediana").tag(FontSize.medium)
                            Text("Grande").tag(FontSize.large)
                        }
                        .font(.system(size: 16))
                        
                        Text("El tamaño de fuente afecta a toda la interfaz de la aplicación.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

struct BehaviorTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Interacción
                VStack(alignment: .leading, spacing: 16) {
                    Text("Interacción")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Toggle("Efectos hápticos", isOn: $preferences.hapticFeedback)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Toggle("Sonidos del sistema", isOn: $preferences.soundEnabled)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Toggle("Cerrar al hacer clic fuera", isOn: $preferences.closeOnOutsideClick)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                    }
                }
                
                // Sección de Notificaciones
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notificaciones")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Toggle("Mostrar notificaciones de copia", isOn: $preferences.showCopyNotifications)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Toggle("Notificaciones de uso", isOn: $preferences.showUsageNotifications)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                    }
                }
                
                // Sección de Inicio
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inicio")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Toggle("Iniciar automáticamente al encender el Mac", isOn: $preferences.launchAtLogin)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Toggle("Mostrar en el Dock", isOn: $preferences.showInDock)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

struct ShortcutsTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Atajos Globales
                VStack(alignment: .leading, spacing: 16) {
                    Text("Atajos Globales")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Toggle("Habilitar atajos globales", isOn: $preferences.globalShortcutEnabled)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        if preferences.globalShortcutEnabled {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Mostrar/Ocultar:")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("⌘⇧P")
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                HStack {
                                    Text("Búsqueda rápida:")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("⌘K")
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                HStack {
                                    Text("Nuevo prompt:")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("⌘N")
                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
                
                // Sección de Atajos en la App
                VStack(alignment: .leading, spacing: 16) {
                    Text("Atajos en la App")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Copiar prompt:")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("⌘C")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        HStack {
                            Text("Editar prompt:")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("⌘E")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        HStack {
                            Text("Eliminar prompt:")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("⌘⌫")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

struct DataTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Binding var showingExportSheet: Bool
    @Binding var showingImportSheet: Bool
    @Binding var showingResetAlert: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sección de Exportación/Importación
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exportación/Importación")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        Button("Exportar datos") {
                            showingExportSheet = true
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .buttonStyle(PlainButtonStyle())
                        
                        Button("Importar datos") {
                            showingImportSheet = true
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Sección de Sincronización
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sincronización")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Toggle("Sincronizar con iCloud", isOn: $preferences.icloudSyncEnabled)
                                .font(.system(size: 16))
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        if preferences.icloudSyncEnabled {
                            Text("Los datos se sincronizarán automáticamente entre tus dispositivos.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .padding(.leading, 16)
                        }
                    }
                }
                
                // Sección de Restablecimiento
                VStack(alignment: .leading, spacing: 16) {
                    Text("Restablecimiento")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Button("Restablecer configuración") {
                        showingResetAlert = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 20)
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
