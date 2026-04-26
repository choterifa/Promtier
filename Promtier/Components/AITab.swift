import SwiftUI
import AppKit

enum ConnectionStatus: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

struct ConnectionStatusDot: View {
    let status: ConnectionStatus
    
    var body: some View {
        ZStack {
            if status == .testing {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .opacity(0.8)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.4), radius: 2)
            }
        }
        .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .secondary.opacity(0.4)
        case .testing: return .blue
        case .success: return .green
        case .failure: return .red
        }
    }
}

struct AITab: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var openAIAvailableModels: [String] = []
    @State private var geminiAvailableModels: [String] = []
    @State private var openRouterAvailableModels: [String] = []
    @State private var ollamaAvailableModels: [String] = []
    
    @State private var isRefreshingOpenAIModels = false
    @State private var isRefreshingGeminiModels = false
    @State private var isRefreshingOpenRouterModels = false
    @State private var isRefreshingOllamaModels = false
    
    @State private var openAIModelsError: String?
    @State private var geminiModelsError: String?
    @State private var openRouterModelsError: String?
    @State private var ollamaModelsError: String?
    
    @State private var openAITestStatus: ConnectionStatus = .idle
    @State private var geminiTestStatus: ConnectionStatus = .idle
    @State private var openRouterTestStatus: ConnectionStatus = .idle
    @State private var ollamaTestStatus: ConnectionStatus = .idle
    
    @State private var showOpenAIKey = false
    @State private var showGeminiKey = false
    @State private var showOpenRouterKey = false
    
    private var fieldWidth: CGFloat {
        min(240, max(130, preferences.windowWidth - 390))
    }

    var body: some View {
        VStack(spacing: 22) {
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
                                preferences.ollamaEnabled = false
                                preferences.preferredAIService = .openai
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                VStack(spacing: 1) {
                    SettingsRow(LocalizedStringKey("api_key".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            if showOpenAIKey {
                                TextField("sk-...", text: $preferences.openAIApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth)
                            } else {
                                SecureField("sk-...", text: $preferences.openAIApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth)
                            }
                            
                            Button(action: { showOpenAIKey.toggle() }) {
                                Image(systemName: showOpenAIKey ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help(showOpenAIKey ? "Ocultar" : "Mostrar")
                        }
                    }

                    Divider().padding(.leading, 20)

                    SettingsRow(LocalizedStringKey("openai_model_id".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            TextField("gpt-4o", text: $preferences.openAIDefaultModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: fieldWidth)

                            Menu {
                                if openAIAvailableModels.isEmpty {
                                    Section("Suggested") {
                                        ForEach(OpenAIService.suggestedChatModels, id: \.self) { model in
                                            Button(model) { preferences.openAIDefaultModel = model }
                                        }
                                    }
                                } else {
                                    Section("Available Models") {
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

                    HStack(spacing: 16) {
                        Spacer()
                        
                        Button(action: { testOpenAIConnection() }) {
                            ConnectionStatusDot(status: openAITestStatus)
                        }
                        .buttonStyle(.plain)
                        .help(openAITestStatus == .idle ? "Probar conexión" : (openAITestStatus == .testing ? "Probando..." : (openAITestStatus == .success ? "Conectado" : "Error de conexión")))

                        Link("Get API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
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
                                preferences.ollamaEnabled = false
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
                                if showGeminiKey {
                                    TextField("Ingresa tu API Key", text: $preferences.geminiAPIKey)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: fieldWidth)
                                } else {
                                    SecureField("Ingresa tu API Key", text: $preferences.geminiAPIKey)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: fieldWidth)
                                }
                                
                                Button(action: { showGeminiKey.toggle() }) {
                                    Image(systemName: showGeminiKey ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, height: 24)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .help(showGeminiKey ? "Ocultar" : "Mostrar")

                            }
                        }

                        SettingsRow(LocalizedStringKey("gemini_model_id".localized(for: preferences.language)),
                                    subtitle: LocalizedStringKey("gemini_model_subtitle".localized(for: preferences.language))) {
                            HStack(spacing: 8) {
                                TextField("gemini-2.5-flash", text: $preferences.geminiDefaultModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: fieldWidth)

                                Menu {
                                    if geminiAvailableModels.isEmpty {
                                        Section("Suggested") {
                                            Button("gemini-2.5-flash • Recomendado") { preferences.geminiDefaultModel = "gemini-2.5-flash" }
                                            Button("gemini-2.5-pro") { preferences.geminiDefaultModel = "gemini-2.5-pro" }
                                        }
                                    } else {
                                        Section("Available Models") {
                                            ForEach(geminiAvailableModels, id: \.self) { model in
                                                Button(model) { preferences.geminiDefaultModel = model }
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
                            }
                        }

                        HStack(spacing: 16) {
                            Spacer()
                            
                            Button(action: { testGeminiConnection() }) {
                                ConnectionStatusDot(status: geminiTestStatus)
                            }
                            .buttonStyle(.plain)
                            .help(geminiTestStatus == .idle ? "Probar conexión" : (geminiTestStatus == .testing ? "Probando..." : (geminiTestStatus == .success ? "Conectado" : "Error de conexión")))

                            Link("Get API Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.trailing, 10)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 8)
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
                                preferences.ollamaEnabled = false
                                preferences.preferredAIService = .openrouter
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                VStack(spacing: 1) {
                    SettingsRow(LocalizedStringKey("api_key".localized(for: preferences.language))) {
                        HStack(spacing: 8) {
                            if showOpenRouterKey {
                                TextField("sk-or-...", text: $preferences.openRouterAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth)
                            } else {
                                SecureField("sk-or-...", text: $preferences.openRouterAPIKey)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: fieldWidth)
                            }
                            
                            Button(action: { showOpenRouterKey.toggle() }) {
                                Image(systemName: showOpenRouterKey ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help(showOpenRouterKey ? "Ocultar" : "Mostrar")
                        }
                    }

                    Divider().padding(.leading, 20)

                    SettingsRow(LocalizedStringKey("openrouter_model_id".localized(for: preferences.language))) {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 8) {
                                TextField("anthropic/claude-3-opus", text: $preferences.openRouterDefaultModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: fieldWidth)

                                Menu {
                                    if openRouterAvailableModels.isEmpty {
                                        Section("Suggested") {
                                            Button("openai/gpt-4o") { preferences.openRouterDefaultModel = "openai/gpt-4o" }
                                            Button("anthropic/claude-3.5-sonnet") { preferences.openRouterDefaultModel = "anthropic/claude-3.5-sonnet" }
                                            Button("google/gemini-2.5-flash") { preferences.openRouterDefaultModel = "google/gemini-2.5-flash" }
                                            Button("meta-llama/llama-3.1-70b-instruct") { preferences.openRouterDefaultModel = "meta-llama/llama-3.1-70b-instruct" }
                                        }
                                    } else {
                                        Section("Available Models") {
                                            ForEach(openRouterAvailableModels, id: \.self) { model in
                                                Button(model) { preferences.openRouterDefaultModel = model }
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
                                .help("openrouter_model_presets".localized(for: preferences.language))
                                
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
                            Link(LocalizedStringKey("openrouter_explore_models".localized(for: preferences.language)), destination: URL(string: "https://openrouter.ai/models")!)
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    HStack(spacing: 16) {
                        Spacer()
                        
                        Button(action: { testOpenRouterConnection() }) {
                            ConnectionStatusDot(status: openRouterTestStatus)
                        }
                        .buttonStyle(.plain)
                        .help(openRouterTestStatus == .idle ? "Probar conexión" : (openRouterTestStatus == .testing ? "Probando..." : (openRouterTestStatus == .success ? "Conectado" : "Error de conexión")))

                        Link("OpenRouter AI", destination: URL(string: "https://openrouter.ai/keys")!)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                .disabled(!preferences.openRouterEnabled)
                .opacity(preferences.openRouterEnabled ? 1 : 0.5)
            }
            
            SettingsSection(title: "Ollama (Local)", icon: "cpu") {
                SettingsRow(
                    "Servicio Ollama",
                    subtitle: "Usar modelos de IA locales con Ollama"
                ) {
                    Toggle("", isOn: Binding(
                        get: { preferences.ollamaEnabled },
                        set: { newValue in
                            preferences.ollamaEnabled = newValue
                            if newValue {
                                preferences.geminiEnabled = false
                                preferences.openAIEnabled = false
                                preferences.openRouterEnabled = false
                                preferences.preferredAIService = .ollama
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                }

                VStack(spacing: 1) {
                    SettingsRow("Base URL") {
                        HStack(spacing: 8) {
                            TextField("http://localhost:11434", text: $preferences.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: fieldWidth)
                        }
                    }

                    Divider().padding(.leading, 20)

                    SettingsRow("Modelo") {
                        HStack(spacing: 8) {
                            TextField("llama3", text: $preferences.ollamaDefaultModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: fieldWidth)

                            Menu {
                                if ollamaAvailableModels.isEmpty {
                                    Section("Suggested") {
                                        Button("llama3") { preferences.ollamaDefaultModel = "llama3" }
                                        Button("mistral") { preferences.ollamaDefaultModel = "mistral" }
                                        Button("gemma") { preferences.ollamaDefaultModel = "gemma" }
                                    }
                                } else {
                                    Section("Available Models") {
                                        ForEach(ollamaAvailableModels, id: \.self) { model in
                                            Button(model) { preferences.ollamaDefaultModel = model }
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
                            .help("Seleccionar modelo local")
                            
                            Button(action: {
                                Task { await refreshOllamaModels() }
                            }) {
                                if isRefreshingOllamaModels {
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
                            .help("Actualizar modelos")
                            .disabled(isRefreshingOllamaModels)
                        }
                    }

                    HStack(spacing: 16) {
                        Spacer()
                        
                        Button(action: { testOllamaConnection() }) {
                            ConnectionStatusDot(status: ollamaTestStatus)
                        }
                        .buttonStyle(.plain)
                        .help(ollamaTestStatus == .idle ? "Probar conexión" : (ollamaTestStatus == .testing ? "Probando..." : (ollamaTestStatus == .success ? "Conectado" : "Error de conexión")))

                        Link("Descargar Ollama", destination: URL(string: "https://ollama.com")!)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                .disabled(!preferences.ollamaEnabled)
                .opacity(preferences.ollamaEnabled ? 1 : 0.5)
            }
            .overlay(alignment: .bottomLeading) {
                if let ollamaModelsError, !ollamaModelsError.isEmpty {
                    Text(ollamaModelsError)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)
                        .padding(.bottom, 10)
                }
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
    
    @MainActor
    private func refreshOllamaModels() async {
        isRefreshingOllamaModels = true
        ollamaModelsError = nil
        defer { isRefreshingOllamaModels = false }

        do {
            let models = try await OllamaService.shared.listModelIDs(baseURL: preferences.ollamaBaseURL)
            ollamaAvailableModels = models
            if !models.contains(preferences.ollamaDefaultModel) {
                if let fromAccount = models.first {
                    preferences.ollamaDefaultModel = fromAccount
                }
            }
        } catch {
            ollamaModelsError = "Ollama models: \(error.localizedDescription)"
        }
    }
    
    private func testOllamaConnection() {
        ollamaTestStatus = .testing
        Task {
            do {
                let success = try await OllamaService.shared.testConnection(baseURL: preferences.ollamaBaseURL)
                await MainActor.run { ollamaTestStatus = success ? .success : .failure("No connection") }
            } catch {
                await MainActor.run { ollamaTestStatus = .failure(error.localizedDescription) }
            }
        }
    }
}
