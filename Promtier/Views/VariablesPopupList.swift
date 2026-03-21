//
//  VariablesPopupList.swift
//  Promtier
//
//  VISTA: Lista flotante para insertar variables ({{variable}} y {{area:variable}})
//

import SwiftUI

struct VariablesPopupList: View {
    @Binding var selectedIndex: Int
    @Binding var triggerSelection: Bool
    let onSelect: (VariableOption) -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    
    struct VariableOption: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let insertionText: String
        let icon: String // Usaremos string corto como "{ }" o "{...}"
    }
    
    // Opciones estáticas a mostrar
    var options: [VariableOption] {
        [
            VariableOption(
                id: "var",
                title: "variable".localized(for: preferences.language),
                subtitle: "{{variable}}",
                insertionText: "{{variable}}",
                icon: "{ }"
            ),
            VariableOption(
                id: "multivar",
                title: "variable_multiline".localized(for: preferences.language),
                subtitle: "{{variable,varia2}}",
                insertionText: "{{variable,varia2}}",
                icon: "{…}"
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Variables")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ESC para cancelar")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            VStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    VariableRow(
                        option: option,
                        isSelected: index == selectedIndex,
                        action: { onSelect(option) }
                    )
                }
            }
            .padding(8)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // Add implicit animation to the row when selection state changes
        .onChange(of: selectedIndex) { _, newIndex in
            DispatchQueue.main.async {
                if newIndex >= options.count {
                    selectedIndex = options.count - 1
                } else if newIndex < 0 {
                    selectedIndex = 0
                }
            }
        }
        .onChange(of: triggerSelection) { _, triggered in
            if triggered {
                let clampedIndex = min(max(0, selectedIndex), options.count - 1)
                onSelect(options[clampedIndex])
                triggerSelection = false
            }
        }
        .onAppear {
            self.selectedIndex = 0
        }
        .onExitCommand {
            onDismiss()
        }
    }
}

private struct VariableRow: View {
    let option: VariablesPopupList.VariableOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.05))
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                    
                    Text(option.icon)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(option.subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // Asegura que toda la fila sea clickeable
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .animation(.none, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
