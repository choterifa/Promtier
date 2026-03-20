//
//  SharedAppPicker.swift
//  Promtier
//
//  COMPONENTES: Selector de aplicaciones compartido para Smart Recommendation y Preferencias
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Estructura para representar una aplicación abierta o instalada
struct RunningApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage
}

/// Popover para buscar y seleccionar aplicaciones de una lista de apps activas
struct AppPickerPopover: View {
    let runningApps: [RunningApp]
    let currentAppID: String?
    let titleKey: String
    let onSelect: (String) -> Void
    let onBrowse: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titleKey.localized(for: preferences.language))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let currentID = currentAppID, let currentApp = runningApps.first(where: { $0.id == currentID }) {
                        AppItemRow(app: currentApp, isCurrent: true, onSelect: onSelect)
                        Divider().padding(.horizontal, 8).padding(.vertical, 4)
                    }
                    
                    let otherApps = runningApps.filter { $0.id != currentAppID }
                    ForEach(otherApps.prefix(12)) { app in
                        AppItemRow(app: app, isCurrent: false, onSelect: onSelect)
                    }
                    
                    Divider().padding(.horizontal, 8).padding(.vertical, 4)
                    
                    Button(action: onBrowse) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .frame(width: 20, height: 20)
                            Text("select_app_title".localized(for: preferences.language))
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 240)
        .padding(.bottom, 8)
    }
}

/// Fila individual para una aplicación en el selector
struct AppItemRow: View {
    let app: RunningApp
    let isCurrent: Bool
    let onSelect: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onSelect(app.id) }) {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                    if isCurrent {
                        Text("current_app".localized(for: PreferencesManager.shared.language))
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Layout básico para etiquetas que fluyen (mejorado en el futuro con Layout protocol)
struct FlowLayout: View {
    var spacing: CGFloat
    var children: [AnyView]

    init<Data: Collection, ID: Hashable, Content: View>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        spacing: CGFloat,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.children = data.map { AnyView(content($0)) }
    }
    
    init(spacing: CGFloat, @ViewBuilder content: () -> AnyView) {
        self.spacing = spacing
        self.children = [content()]
    }
    
    init<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.children = [AnyView(content())]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: spacing) {
                ForEach(0..<children.count, id: \.self) { i in
                    children[i]
                }
            }
        }
    }
}

/// Utilidades de NSWorkspace para el selector de apps
extension NSWorkspace {
    func getRelevantRunningApps() -> [RunningApp] {
        let running = self.runningApplications
        return running.compactMap { app in
            guard let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  let icon = app.icon,
                  app.activationPolicy == .regular,
                  bundleID != Bundle.main.bundleIdentifier else { return nil }
            return RunningApp(id: bundleID, name: name, icon: icon)
        }
    }
}
