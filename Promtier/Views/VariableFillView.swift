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
    
    private var processedContent: String {
        var result = prompt.content
        for variable in variables {
            let value = variableValues[variable] ?? ""
            if !value.isEmpty {
                // Patrón robusto: busca {{ variable }} con espacios opcionales
                let escapedVar = NSRegularExpression.escapedPattern(for: variable)
                let pattern = "\\{\\{\\s*\(escapedVar)\\s*\\}\\}"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: value)
                }
            }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rellenar Variables")
                        .font(.system(size: 18 * preferences.fontSize.scale, weight: .bold))
                    Text(prompt.title)
                        .font(.system(size: 11 * preferences.fontSize.scale))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider().padding(.horizontal, 24)
            
            // Lista de campos
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(variables, id: \.self) { variable in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(variable.uppercased())
                                    .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                                    .foregroundColor(.blue)
                                    .tracking(1.2)
                                
                                Spacer()
                                
                                if focusedField == variable {
                                    Text("Escribiendo...")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.blue.opacity(0.6))
                                }
                            }
                            
                            TextField("Valor para \(variable)...", text: Binding(
                                get: { variableValues[variable, default: ""] },
                                set: { variableValues[variable] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(focusedField == variable ? Color.blue.opacity(0.04) : Color.primary.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == variable ? Color.blue.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1.5)
                                    )
                            )
                            .focused($focusedField, equals: variable)
                            .onSubmit {
                                handleSubmission(for: variable)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(28)
            }
            
            // Sección de Previsualización
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("VISTA PREVIA", systemImage: "eye.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                
                ScrollView {
                    Text(processedContent.isEmpty ? "La vista previa aparecerá aquí..." : processedContent)
                        .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                        .foregroundColor(processedContent.isEmpty ? .secondary.opacity(0.4) : .primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                }
                .frame(maxHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            
            Divider().padding(.horizontal, 24)
            
            // Footer
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    onCopy(processedContent)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                        Text("Copiar Prompt Final")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canCopy ? Color.blue : Color.gray.opacity(0.3))
                            .shadow(color: canCopy ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!canCopy)
            }
            .padding(28)
        }
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let firstVar = variables.first {
                    focusedField = firstVar
                }
            }
        }
    }
    
    private var canCopy: Bool {
        !variableValues.isEmpty && !variableValues.values.allSatisfy { $0.isEmpty }
    }
    
    private func handleSubmission(for currentVariable: String) {
        let allVars = variables
        if let currentIndex = allVars.firstIndex(of: currentVariable) {
            if currentIndex < allVars.count - 1 {
                // Saltar al siguiente campo
                focusedField = allVars[currentIndex + 1]
            } else {
                // Es el último: copiar y cerrar si hay contenido
                if canCopy {
                    onCopy(processedContent)
                }
            }
        }
    }
}
