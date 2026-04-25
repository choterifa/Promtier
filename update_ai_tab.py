import re
import sys

def main():
    try:
        with open('Promtier/Components/AITab.swift', 'r') as f:
            content = f.read()
            
        # 1. Add State variables for Gemini and OpenRouter models
        state_vars_to_add = """    @State private var openAIAvailableModels: [String] = []
    @State private var geminiAvailableModels: [String] = []
    @State private var openRouterAvailableModels: [String] = []
    
    @State private var isRefreshingOpenAIModels = false
    @State private var isRefreshingGeminiModels = false
    @State private var isRefreshingOpenRouterModels = false
    
    @State private var openAIModelsError: String?
    @State private var geminiModelsError: String?
    @State private var openRouterModelsError: String?"""
        
        content = re.sub(
            r'''    @State private var openAIAvailableModels: \[String\] = \[\]
\s+@State private var isRefreshingOpenAIModels = false
\s+@State private var openAIModelsError: String\?''',
            state_vars_to_add,
            content
        )
        
        # 2. Modify Gemini model selection UI
        gemini_ui_pattern = r'''Menu \{\s*Section\("Gemini 2\.5"\) \{.*?\Section\("Gemini 2\.0"\) \{.*?\}\s*\} label:'''
        
        gemini_ui_replacement = """Menu {
                                    Section("Suggested") {
                                        Button("gemini-2.5-pro") { preferences.geminiDefaultModel = "gemini-2.5-pro" }
                                        Button("gemini-2.5-flash • Recomendado") { preferences.geminiDefaultModel = "gemini-2.5-flash" }
                                        Button("gemini-2.0-pro-exp-02-05") { preferences.geminiDefaultModel = "gemini-2.0-pro-exp-02-05" }
                                        Button("gemini-2.0-flash") { preferences.geminiDefaultModel = "gemini-2.0-flash" }
                                        Button("gemini-2.0-flash-lite") { preferences.geminiDefaultModel = "gemini-2.0-flash-lite" }
                                    }
                                    if !geminiAvailableModels.isEmpty {
                                        Section("From your account") {
                                            ForEach(geminiAvailableModels, id: \.self) { model in
                                                Button(model) { preferences.geminiDefaultModel = model }
                                            }
                                        }
                                    }
                                } label:"""
        content = re.sub(gemini_ui_pattern, gemini_ui_replacement, content, flags=re.DOTALL)
        
        # Add refresh button for Gemini
        gemini_refresh_btn = """
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("gemini_model_presets".localized(for: preferences.language))
                            
                            Button(action: {
                                Task { await refreshGeminiModels() }
                            }) {
                                if isRefreshingGeminiModels {
                                    ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(4)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("refresh_models".localized(for: preferences.language))
                            .disabled(isRefreshingGeminiModels || preferences.geminiAPIKey.isEmpty)"""
        
        content = re.sub(
            r'''\}\s*\.menuStyle\(\.button\)\s*\.buttonStyle\(\.plain\)\s*\.fixedSize\(\)\s*\.help\("gemini_model_presets"\.localized\(for: preferences\.language\)\)''',
            gemini_refresh_btn,
            content
        )

        # 3. Modify OpenRouter model selection UI
        old_openrouter_menu = """                            Menu {
                                Section("Suggested") {
                                    ForEach(OpenAIService.suggestedChatModels, id: \.self) { model in
                                        Button(model) { preferences.openRouterDefaultModel = model }
                                    }
                                }
                            } label:"""
                            
        new_openrouter_menu = """                            Menu {
                                Section("Suggested") {
                                    ForEach(OpenAIService.suggestedChatModels, id: \.self) { model in
                                        Button(model) { preferences.openRouterDefaultModel = model }
                                    }
                                }
                                if !openRouterAvailableModels.isEmpty {
                                    Section("From your account") {
                                        ForEach(openRouterAvailableModels, id: \.self) { model in
                                            Button(model) { preferences.openRouterDefaultModel = model }
                                        }
                                    }
                                }
                            } label:"""
        
        content = content.replace(old_openrouter_menu, new_openrouter_menu)

        old_openrouter_button = """                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("openai_model_presets".localized(for: preferences.language))
                        }
                    }
                }
                .disabled(!preferences.openRouterEnabled)"""
        
        new_openrouter_button = """                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("openai_model_presets".localized(for: preferences.language))
                            
                            Button(action: {
                                Task { await refreshOpenRouterModels() }
                            }) {
                                if isRefreshingOpenRouterModels {
                                    ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(4)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("refresh_models".localized(for: preferences.language))
                            .disabled(isRefreshingOpenRouterModels || preferences.openRouterAPIKey.isEmpty)
                        }
                    }
                }
                .disabled(!preferences.openRouterEnabled)"""
        
        parts = content.split('SettingsSection(title: "OpenRouter", icon: "network")')
        if len(parts) > 1:
            parts[1] = parts[1].replace(old_openrouter_button, new_openrouter_button)
            content = 'SettingsSection(title: "OpenRouter", icon: "network")'.join(parts)
            
        # 4. Add refresh methods
        refresh_methods = """
    @MainActor
    private func refreshGeminiModels() async {
        guard !preferences.geminiAPIKey.isEmpty else { return }
        isRefreshingGeminiModels = true
        geminiModelsError = nil
        defer { isRefreshingGeminiModels = false }

        do {
            let models = try await GeminiService.shared.listModelIDs(apiKey: preferences.geminiAPIKey)
            geminiAvailableModels = models
            if !models.contains(preferences.geminiDefaultModel) {
                if let fromAccount = models.first {
                    preferences.geminiDefaultModel = fromAccount
                }
            }
        } catch {
            geminiModelsError = "Gemini models: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func refreshOpenRouterModels() async {
        guard !preferences.openRouterAPIKey.isEmpty else { return }
        isRefreshingOpenRouterModels = true
        openRouterModelsError = nil
        defer { isRefreshingOpenRouterModels = false }

        do {
            let models = try await OpenAIService.shared.listModelIDs(apiKey: preferences.openRouterAPIKey, isOpenRouter: true)
            openRouterAvailableModels = models
            if !models.contains(preferences.openRouterDefaultModel) {
                if let fromAccount = models.first {
                    preferences.openRouterDefaultModel = fromAccount
                } else if let suggested = OpenAIService.suggestedChatModels.first {
                    preferences.openRouterDefaultModel = suggested
                }
            }
        } catch {
            openRouterModelsError = "OpenRouter models: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func handleOpenAIKeyChanged() async {"""
        
        target_str = '''    @MainActor
    private func handleOpenAIKeyChanged() async {'''
        content = content.replace(target_str, refresh_methods)

        with open('Promtier/Components/AITab.swift', 'w') as f:
            f.write(content)
            
        print("Successfully updated AITab.swift")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()