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
    @State private var showAIPlayground: Bool = false
    
    enum VariableType: Equatable {
        case text
        case multiline
        case selection(options: [String])
        case date
        case time
        case smart(placeholder: String)
    }
    
    struct TemplateVariable: Identifiable, Hashable {
        let id: String
        let name: String
        let type: VariableType
        
        static func == (lhs: TemplateVariable, rhs: TemplateVariable) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }
    
    // MARK: - Computeds
    
    private var variables: [TemplateVariable] {
        let rawVars = prompt.extractTemplateVariables()
        var vars: [TemplateVariable] = []
        
        for raw in rawVars {
            if !preferences.isPremiumActive {
                vars.append(TemplateVariable(id: raw, name: raw, type: .text))
                continue
            }
            
            let lower = raw.lowercased()
            if lower == "date" || lower == "fecha" {
                vars.append(TemplateVariable(id: raw, name: raw, type: .date))
                continue
            }
            if lower == "time" || lower == "hora" {
                vars.append(TemplateVariable(id: raw, name: raw, type: .time))
                continue
            }
            
            // 1. Caso area/multi/multiline (Solo si tiene comas para ser lista)
            if raw.hasPrefix("area:") || raw.hasPrefix("multiline:") || raw.hasPrefix("multi:") {
                let parts = raw.components(separatedBy: ":")
                if parts.count == 2 {
                    let optionsStr = parts[1]
                    if optionsStr.contains(",") {
                        let options = optionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let label = parts[0].replacingOccurrences(of: "area:", with: "")
                                           .replacingOccurrences(of: "multiline:", with: "")
                                           .replacingOccurrences(of: "multi:", with: "")
                                           .trimmingCharacters(in: .whitespaces).uppercased()
                        let finalName = label.isEmpty ? "SELECT OPTION".localized(for: preferences.language) : label
                        vars.append(TemplateVariable(id: raw, name: finalName, type: .selection(options: options)))
                    } else {
                        // "Impidelo": No lo agregamos como variable si no tiene comas
                        continue
                    }
                }
                continue
            }
            
            // 2. Selección con Label estándar (e.g., {{Label:Op1,Op2}})
            if raw.contains(":") {
                let parts = raw.components(separatedBy: ":")
                if parts.count == 2 {
                    let label = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
                    let optionsStr = parts[1]
                    
                    if optionsStr.contains(",") {
                        let options = optionsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        vars.append(TemplateVariable(id: raw, name: label, type: .selection(options: options)))
                    } else {
                        // Valor único con label: {{Label:Default}}
                        vars.append(TemplateVariable(id: raw, name: label, type: .text))
                    }
                }
                continue
            }
            
            // 3. Selección sin Label: {{Op1,Op2}}
            if raw.contains(",") {
                let options = raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if options.count > 1 {
                    vars.append(TemplateVariable(id: raw, name: "SELECT OPTION".localized(for: preferences.language), type: .selection(options: options)))
                }
                continue
            }
            
            // 4. Smart Placeholders (clipboard, date, etc)
            if PlaceholderResolver.isSmart(raw) {
                vars.append(TemplateVariable(id: raw, name: raw.uppercased(), type: .smart(placeholder: raw)))
                continue
            }
            
            // 5. Texto normal: {{Variable}}
            vars.append(TemplateVariable(id: raw, name: raw, type: .text))
        }
        
        return vars
    }
    
    private var hasPremiumVariables: Bool {
        let rawVars = prompt.extractTemplateVariables()
        return rawVars.contains { raw in
            let lower = raw.lowercased()
            return lower == "date" || lower == "fecha" || lower == "time" || lower == "hora" || (raw.contains(":") && raw.contains(","))
        }
    }
    
    private var processedContent: String {
        var result = prompt.content
        let rawVars = prompt.extractTemplateVariables()
        
        for rawVar in rawVars {
            let value = variableValues[rawVar] ?? ""
            if !value.isEmpty {
                let escapedVar = NSRegularExpression.escapedPattern(for: rawVar)
                let pattern = "\\{\\{\\s*\(escapedVar)\\s*\\}\\}"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: value)
                }
            }
        }
        return result
    }
    private var currentCategoryColor: Color {
        if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
            return category.color
        }
        return .blue
    }
    
    private var canCopy: Bool {
        let allIds = variables.map { $0.id }
        if allIds.isEmpty { return true }
        return allIds.allSatisfy { id in
            !(variableValues[id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    // MARK: - Body
    
    var body: some View {
        Group {
            if hasPremiumVariables && !preferences.isPremiumActive {
                PremiumUpsellView(featureName: "advanced_variables".localized(for: preferences.language), onCancel: onCancel)
                    .cornerRadius(24)
            } else {
                mainContainer
            }
        }
    }
    
    private var mainContainer: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider().padding(.horizontal, 24)
            
            HStack(spacing: 0) {
                // Columna Izquierda: Formulario de Variables
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            variablesGrid(proxy: proxy)
                        }
                        .scrollIndicators(.never)
                        .onChange(of: focusedField) { _, newValue in
                            if let id = newValue {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(width: 1).background(Color.primary.opacity(0.05))
                
                // Columna Derecha: Preview en Tiempo Real
                VStack(spacing: 0) {
                    previewArea
                }
                .frame(width: 320)
                .background(Color.primary.opacity(0.01))
            }
            
            Divider().padding(.horizontal, 24)
            
            footerSection
        }
        .frame(width: 780, height: preferences.windowHeight * 0.85)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            // Inicializar valores por defecto para selecciones y variables con valor predefinido
            for variable in variables {
                if variableValues[variable.id] == nil {
                    switch variable.type {
                    case .selection(let options):
                        variableValues[variable.id] = options.first ?? ""
                    case .smart(let id):
                        if let resolved = PlaceholderResolver.shared.resolve(id) {
                            variableValues[variable.id] = resolved
                        }
                    case .text:
                        // Si es del tipo {{Label:Valor}}, extraer el Valor como valor inicial
                        if variable.id.contains(":") {
                            let parts = variable.id.components(separatedBy: ":")
                            if parts.count == 2 {
                                variableValues[variable.id] = parts[1].trimmingCharacters(in: .whitespaces)
                            }
                        }
                    default: break
                    }
                }
            }
            
            // Determinar el primer campo manual para el foco
            let firstManualField = variables.first { variable in
                if case .smart = variable.type { return false }
                return true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = firstManualField?.id ?? variables.first?.id
            }
        }
        .onCommand(#selector(NSText.copy(_:))) {
            if canCopy {
                HapticService.shared.playImpact()
                onCopy(processedContent)
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("fill_variables".localized(for: preferences.language))
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
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private func variablesGrid(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 20) {
            ForEach(variables) { variable in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(variable.name.uppercased())
                            .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                            .foregroundColor(currentCategoryColor)
                            .tracking(1.2)
                        
                        Spacer()
                        
                        if focusedField == variable.id {
                            Text(statusText(for: variable.type))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(currentCategoryColor.opacity(0.6))
                        }
                    }
                    
                    inputField(for: variable)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(focusedField == variable.id ? currentCategoryColor.opacity(0.04) : Color.primary.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == variable.id ? currentCategoryColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1.5)
                        )
                }
                .id(variable.id)
            }
        }
        .padding(28)
    }
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("preview".localized(for: preferences.language).uppercased(), systemImage: "eye.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(currentCategoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(currentCategoryColor.opacity(0.1))
                    .cornerRadius(6)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.5), radius: 2)
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                if preferences.ollamaEnabled {
                    Button(action: { 
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIPlayground.toggle()
                        }
                    }) {
                        Image(systemName: showAIPlayground ? "sparkles.rectangle.stack.fill" : "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(showAIPlayground ? .purple : currentCategoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(showAIPlayground ? Color.purple.opacity(0.1) : currentCategoryColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("local_ai_ollama".localized(for: preferences.language))
                }
            }
            
            ScrollView {
                Text(processedContent.isEmpty ? "preview_placeholder".localized(for: preferences.language) : processedContent)
                    .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                    .foregroundColor(processedContent.isEmpty ? .secondary.opacity(0.4) : .primary.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(16)
            }
            .background(
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    Color.primary.opacity(0.01)
                }
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            
            if showAIPlayground && preferences.ollamaEnabled {
                AIPlaygroundView(prompt: processedContent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(height: 280)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }
    
    private var footerSection: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Text("cancel".localized(for: preferences.language))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Button(action: {
                HapticService.shared.playImpact()
                onCopy(processedContent)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                    Text("copy_final_prompt".localized(for: preferences.language))
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canCopy ? currentCategoryColor : Color.gray.opacity(0.3))
                        .shadow(color: canCopy ? currentCategoryColor.opacity(0.3) : .clear, radius: 8, y: 4)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canCopy)
            .keyboardShortcut("c", modifiers: [.command]) 
            .keyboardShortcut(.return, modifiers: [.command]) 
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private func inputField(for variable: TemplateVariable) -> some View {
        Group {
            switch variable.type {
            case .text:
                TextField(String(format: "value_for".localized(for: preferences.language), variable.name), text: Binding(
                    get: { variableValues[variable.id, default: ""] },
                    set: { variableValues[variable.id] = $0 }
                ))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: variable.id)
                .onSubmit { handleSubmission(for: variable.id) }
                
            case .multiline:
                TextEditor(text: Binding(
                    get: { variableValues[variable.id, default: ""] },
                    set: { variableValues[variable.id] = $0 }
                ))
                .frame(minHeight: 100) // Un poco más alto ahora que hay espacio
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: variable.id)
                
            case .selection(let options):
                Picker("", selection: Binding(
                    get: { variableValues[variable.id, default: options.first ?? ""] },
                    set: { variableValues[variable.id] = $0 }
                )) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .focused($focusedField, equals: variable.id)
                
            case .date, .time:
                DatePicker("", selection: Binding(
                    get: { Date() },
                    set: { variableValues[variable.id] = dateString(from: $0, type: variable.type) }
                ), displayedComponents: (variable.type == VariableType.date) ? DatePickerComponents.date : DatePickerComponents.hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .focused($focusedField, equals: variable.id)
                
            case .smart:
                TextField(String(format: "value_for".localized(for: preferences.language), variable.name), text: Binding(
                    get: { variableValues[variable.id, default: ""] },
                    set: { variableValues[variable.id] = $0 }
                ))
                .textFieldStyle(.plain)
                .focused($focusedField, equals: variable.id)
                .onSubmit { handleSubmission(for: variable.id) }
            }
        }
    }

    // MARK: - Helpers
    
    private func handleSubmission(for variableId: String) {
        let allIds = variables.map { $0.id }
        if let currentIndex = allIds.firstIndex(of: variableId) {
            if currentIndex < allIds.count - 1 {
                withAnimation {
                    focusedField = allIds[currentIndex + 1]
                }
            } else {
                if canCopy {
                    HapticService.shared.playImpact()
                    onCopy(processedContent)
                }
            }
        }
    }
    
    private func statusText(for type: VariableType) -> String {
        switch type {
        case .text, .multiline: return "typing".localized(for: preferences.language)
        case .selection: return "selecting".localized(for: preferences.language)
        case .date, .time: return "choosing".localized(for: preferences.language)
        case .smart: return "Auto-filled".localized(for: preferences.language)
        }
    }
    
    private func dateString(from date: Date, type: VariableType) -> String {
        let formatter = DateFormatter()
        switch type {
        case .date:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .time:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        default: return ""
        }
        return formatter.string(from: date)
    }
}
