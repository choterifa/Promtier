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
    
    enum VariableType: Equatable {
        case text
        case selection(options: [String])
        case date
        case time
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
        return rawVars.map { raw in
            if !preferences.isPremiumActive {
                return TemplateVariable(id: raw, name: raw, type: .text)
            }
            
            if raw.lowercased() == "date" || raw.lowercased() == "fecha" {
                return TemplateVariable(id: raw, name: raw, type: .date)
            }
            if raw.lowercased() == "time" || raw.lowercased() == "hora" {
                return TemplateVariable(id: raw, name: raw, type: .time)
            }
            
            if raw.contains(":") && raw.contains(",") {
                let parts = raw.components(separatedBy: ":")
                if parts.count == 2 {
                    let label = parts[0].trimmingCharacters(in: .whitespaces)
                    let options = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    return TemplateVariable(id: raw, name: label, type: .selection(options: options))
                }
            }
            
            return TemplateVariable(id: raw, name: raw, type: .text)
        }
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
            
            ScrollViewReader { proxy in
                ScrollView {
                    variablesGrid(proxy: proxy)
                }
                .onChange(of: focusedField) { _, newValue in
                    if let id = newValue {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            
            previewArea
            
            Divider().padding(.horizontal, 24)
            
            footerSection
        }
        .frame(width: 520, height: preferences.windowHeight * 0.90)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = variables.first?.id
            }
        }
        .onCommand(Selector(("copy:"))) {
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
        VStack(spacing: 24) {
            ForEach(variables) { variable in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(variable.name.uppercased())
                            .font(.system(size: 10 * preferences.fontSize.scale, weight: .bold))
                            .foregroundColor(.blue)
                            .tracking(1.2)
                        
                        Spacer()
                        
                        if focusedField == variable.id {
                            Text(statusText(for: variable.type))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.blue.opacity(0.6))
                        }
                    }
                    
                    inputField(for: variable)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(focusedField == variable.id ? Color.blue.opacity(0.02) : Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == variable.id ? Color.blue.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1.5)
                        )
                }
                .id(variable.id)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
            }
        }
        .padding(28)
    }
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("preview".localized(for: preferences.language).uppercased(), systemImage: "eye.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))
                Spacer()
            }
            
            ScrollView {
                Text(processedContent.isEmpty ? "preview_placeholder".localized(for: preferences.language) : processedContent)
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
                        .fill(canCopy ? Color.blue : Color.gray.opacity(0.3))
                        .shadow(color: canCopy ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canCopy)
            .keyboardShortcut("c", modifiers: [.command]) 
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
        case .text: return "typing".localized(for: preferences.language)
        case .selection: return "selecting".localized(for: preferences.language)
        case .date, .time: return "choosing".localized(for: preferences.language)
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
