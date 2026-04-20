import SwiftUI
import AppKit

enum ConnectionStatus: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

struct TestConnectionButton: View {
    let status: ConnectionStatus
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if status == .testing {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.5)
                } else if status == .success {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else if case .failure = status {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                } else {
                    Image(systemName: "network").foregroundColor(.blue)
                }
            }
            .frame(width: 24, height: 24)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help("Probar Conexión")
    }
}

struct AITab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var openAIAvailableModels: [String] = []
    @State private var isRefreshingOpenAIModels = false
    @State private var openAIModelsError: String?
    
    @State private var openAITestStatus: ConnectionStatus = .idle
    @State private var geminiTestStatus: ConnectionStatus = .idle
    @State private var openRouterTestStatus: ConnectionStatus = .idle

    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "OpenAI ChatGPT", icon: "cloud.fill") {
                SettingsRow(
                    LocalizedStringKey("openai_service".localized(for: preferences.language)),
                    subtitle: LocalizedStringKey("openai_subtitle".localized(for: preferences.language))
                ) {
                    Toggle("", isOn: Binding(
                        get: { preferences.openAIEnabled },
                        set: { newValue in
                            preferences.openAIEnabled = newValue
                            if newValue {
                                preferences.geminiEnabled = false
                                preferences.openRouterEnabled = false
                                preferences.preferredAIService = .openai
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                VStack(spacing: 1) {
                    SettingsRow(LocalizedStringKey("api_key".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            SecureField("sk-...", text: $preferences.openAIApiKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            
                            Button(action: {
                                if let pasted = NSPasteboard.general.string(forType: .string) {
                                    let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    preferences.openAIApiKey = trimmed
                                    HapticService.shared.playLight()
                                    Task { await handleOpenAIKeyChanged() }
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("paste".localized(for: preferences.language))
                            
                            TestConnectionButton(status: openAITestStatus) {
                                testOpenAIConnection()
                            }
                        }
                    }

                    Divider().padding(.leading, 20)

                    SettingsRow(LocalizedStringKey("openai_model_id".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            TextField("gpt-4o", text: $preferences.openAIDefaultModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Menu {
                                Section("Suggested") {
                                    ForEach(OpenAIService.suggestedChatModels, id: \.self) { model in
                                        Button(model) { preferences.openAIDefaultModel = model }
                                    }
                                }

                                if !openAIAvailableModels.isEmpty {
                                    Section("From your account") {
                                        ForEach(openAIAvailableModels, id: \.self) { model in
                                            Button(model) { preferences.openAIDefaultModel = model }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "list.bullet.indent")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(4)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("openai_model_presets".localized(for: preferences.language))

                            Button(action: {
                                Task { await refreshOpenAIModels() }
                            }) {
                                if isRefreshingOpenAIModels {
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
                            .disabled(isRefreshingOpenAIModels || preferences.openAIApiKey.isEmpty)
                        }
                    }
                }
                .disabled(!preferences.openAIEnabled)
                .opacity(preferences.openAIEnabled ? 1 : 0.55)
            }
            .overlay(alignment: .bottomLeading) {
                if let openAIModelsError, !openAIModelsError.isEmpty {
                    Text(openAIModelsError)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)
                        .padding(.bottom, 10)
                }
            }
            
            SettingsSection(title: "Google Gemini", icon: "sparkles") {
                SettingsRow(
                    LocalizedStringKey("gemini_service".localized(for: preferences.language)),
                    subtitle: LocalizedStringKey("gemini_subtitle".localized(for: preferences.language))
                ) {
                    Toggle("", isOn: Binding(
                        get: { preferences.geminiEnabled },
                        set: { newValue in
                            preferences.geminiEnabled = newValue
                            if newValue {
                                preferences.openAIEnabled = false
                                preferences.openRouterEnabled = false
                                preferences.preferredAIService = .gemini
                            }
                        }
                    ))
                        .toggleStyle(.switch)
                }
                
                if preferences.geminiEnabled {
                    VStack(spacing: 12) {
                        SettingsRow("API Key", subtitle: "Clave de API de Google Gemini") {
                            HStack(spacing: 8) {
                                SecureField("Ingresa tu API Key", text: $preferences.geminiAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                                
                                Button(action: {
                                    if let pasted = NSPasteboard.general.string(forType: .string) {
                                        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                        preferences.geminiAPIKey = trimmed
                                        HapticService.shared.playLight()
                                    }
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 13))
                                        .foregroundColor(.blue)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .help("paste".localized(for: preferences.language))
                                
                                TestConnectionButton(status: geminiTestStatus) {
                                    testGeminiConnection()
                                }
                            }
                        }

                        SettingsRow(LocalizedStringKey("gemini_model_id".localized(for: preferences.language)),
                                    subtitle: LocalizedStringKey("gemini_model_subtitle".localized(for: preferences.language))) {
                            HStack(spacing: 8) {
                                TextField("gemini-2.5-flash", text: $preferences.geminiDefaultModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 200)

                                Menu {
                                    Section("Gemini 2.5") {
                                        Button("gemini-2.5-pro") { preferences.geminiDefaultModel = "gemini-2.5-pro" }
                                        Button("gemini-2.5-flash • Recomendado") { preferences.geminiDefaultModel = "gemini-2.5-flash" }
                                    }
                                    Section("Gemini 2.0") {
                                        Button("gemini-2.0-pro-exp-02-05") { preferences.geminiDefaultModel = "gemini-2.0-pro-exp-02-05" }
                                        Button("gemini-2.0-flash") { preferences.geminiDefaultModel = "gemini-2.0-flash" }
                                        Button("gemini-2.0-flash-lite") { preferences.geminiDefaultModel = "gemini-2.0-flash-lite" }
                                    }
                                    Section("Gemini 1.5") {
                                        Button("gemini-1.5-pro") { preferences.geminiDefaultModel = "gemini-1.5-pro" }
                                        Button("gemini-1.5-flash") { preferences.geminiDefaultModel = "gemini-1.5-flash" }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet.indent")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(4)
                                }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                                .fixedSize()
                            }
                        }
                    }
                    .padding(.leading, 20)
                }
            }

            SettingsSection(title: "OpenRouter", icon: "network") {
                SettingsRow(
                    LocalizedStringKey("openrouter_service".localized(for: preferences.language)),
                    subtitle: LocalizedStringKey("openrouter_subtitle".localized(for: preferences.language))
                ) {
                    Toggle("", isOn: Binding(
                        get: { preferences.openRouterEnabled },
                        set: { newValue in
                            preferences.openRouterEnabled = newValue
                            if newValue {
                                preferences.geminiEnabled = false
                                preferences.openAIEnabled = false
                                preferences.preferredAIService = .openrouter
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                VStack(spacing: 1) {
                    SettingsRow(LocalizedStringKey("api_key".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            SecureField("sk-or-...", text: $preferences.openRouterAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            
                            Button(action: {
                                if let pasted = NSPasteboard.general.string(forType: .string) {
                                    let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                    preferences.openRouterAPIKey = trimmed
                                    HapticService.shared.playLight()
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("paste".localized(for: preferences.language))
                            
                            TestConnectionButton(status: openRouterTestStatus) {
                                testOpenRouterConnection()
                            }
                        }
                    }

                    Divider().padding(.leading, 20)

                    SettingsRow(LocalizedStringKey("openrouter_model_id".localized(for: preferences.language))) {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 8) {
                                TextField("anthropic/claude-3-opus", text: $preferences.openRouterDefaultModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 320)
                            }
                            Link(LocalizedStringKey("openrouter_explore_models".localized(for: preferences.language)), destination: URL(string: "https://openrouter.ai/models")!)
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .disabled(!preferences.openRouterEnabled)
                .opacity(preferences.openRouterEnabled ? 1 : 0.5)
            }
            
            Text(LocalizedStringKey("security_notice".localized(for: preferences.language)))
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
    }

    @MainActor
    private func refreshOpenAIModels() async {
        guard !preferences.openAIApiKey.isEmpty else { return }
        isRefreshingOpenAIModels = true
        openAIModelsError = nil
        defer { isRefreshingOpenAIModels = false }

        do {
            let models = try await OpenAIService.shared.listModelIDs(apiKey: preferences.openAIApiKey)
            openAIAvailableModels = models
            // Si el modelo actual ya no es válido, escoger uno sugerido o de la cuenta
            if !models.contains(preferences.openAIDefaultModel) {
                if let fromAccount = models.first {
                    preferences.openAIDefaultModel = fromAccount
                } else if let suggested = OpenAIService.suggestedChatModels.first {
                    preferences.openAIDefaultModel = suggested
                }
            }
        } catch {
            openAIModelsError = "OpenAI models: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleOpenAIKeyChanged() async {
        guard !preferences.openAIApiKey.isEmpty else {
            openAIAvailableModels = []
            openAIModelsError = nil
            return
        }
        await refreshOpenAIModels()
    }
    
    private func testOpenAIConnection() {
        guard !preferences.openAIApiKey.isEmpty else { return }
        openAITestStatus = .testing
        Task {
            do {
                let success = try await OpenAIService.shared.testConnection(apiKey: preferences.openAIApiKey)
                await MainActor.run { openAITestStatus = success ? .success : .failure("Invalid Key") }
            } catch {
                await MainActor.run { openAITestStatus = .failure(error.localizedDescription) }
            }
        }
    }
    
    private func testGeminiConnection() {
        guard !preferences.geminiAPIKey.isEmpty else { return }
        geminiTestStatus = .testing
        Task {
            do {
                let success = try await GeminiService.shared.testConnection(apiKey: preferences.geminiAPIKey)
                await MainActor.run { geminiTestStatus = success ? .success : .failure("Invalid Key") }
            } catch {
                await MainActor.run { geminiTestStatus = .failure(error.localizedDescription) }
            }
        }
    }
    
    private func testOpenRouterConnection() {
        guard !preferences.openRouterAPIKey.isEmpty else { return }
        openRouterTestStatus = .testing
        Task {
            do {
                let success = try await OpenAIService.shared.testConnection(apiKey: preferences.openRouterAPIKey, isOpenRouter: true)
                await MainActor.run { openRouterTestStatus = success ? .success : .failure("Invalid Key") }
            } catch {
                await MainActor.run { openRouterTestStatus = .failure(error.localizedDescription) }
            }
        }
    }
}