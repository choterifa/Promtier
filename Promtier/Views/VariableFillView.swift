//
//  VariableFillView.swift
//  Promtier
//
//  VISTA: Formulario dinámico para rellenar variables {{variable}}
//

import SwiftUI

struct VariableFillView: View {
    let prompt: Prompt
    let onCopy: (String) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var variableValues: [String: String] = [:]
    @FocusState private var focusedField: String?
    
    private var variables: [String] {
        prompt.extractTemplateVariables()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rellenar Variables")
                        .font(.system(size: 18 * preferences.fontSize.scale, weight: .bold))
                    Text(prompt.title)
                        .font(.system(size: 13 * preferences.fontSize.scale))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            
            Divider().padding(.horizontal, 24)
            
            // Lista de campos
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(variables, id: \.self) { variable in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(variable.uppercased())
                                .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                                .foregroundColor(.blue)
                                .tracking(1)
                            
                            TextField("Ingresa el valor para \(variable)...", text: Binding(
                                get: { variableValues[variable, default: ""] },
                                set: { variableValues[variable] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(focusedField == variable ? Color.blue.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: 1)
                                    )
                            )
                            .focused($focusedField, equals: variable)
                        }
                    }
                }
                .padding(24)
            }
            
            Divider().padding(.horizontal, 24)
            
            // Footer
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    var finalContent = prompt.content
                    // Reemplazar cada variable encontrada en el prompt
                    for variable in variables {
                        let value = variableValues[variable] ?? ""
                        // Reemplazar la etiqueta exacta {{variable}} por su valor
                        finalContent = finalContent.replacingOccurrences(of: "{{\(variable)}}", with: value)
                    }
                    onCopy(finalContent)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copiar Prompt Final")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(variableValues.values.contains { $0.isEmpty } || variableValues.count < variables.count)
            }
            .padding(24)
        }
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(20)
        .onAppear {
            if let firstVar = variables.first {
                focusedField = firstVar
            }
        }
    }
}
