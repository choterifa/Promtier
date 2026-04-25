import re

with open('Promtier/Services/AIServiceManager.swift', 'r') as f:
    content = f.read()

# Replace everything from `private var cooldowns` down to just before `func generatePromptMetadata`
# with the simple version of `func generate`

new_content = re.sub(
    r"    // Almacena hasta cuándo está deshabilitado temporalmente un servicio.*?// MARK: - Generación de Metadatos Comunes",
    """    enum AIError: LocalizedError {
        case serviceDisabled
        case invalidAPIKey(String)
        case configurationError
        
        var errorDescription: String? {
            switch self {
            case .serviceDisabled: return "El servicio de IA seleccionado está desactivado en Preferencias."
            case .invalidAPIKey(let service): return "Falta la clave API para \(service)."
            case .configurationError: return "Error de configuración en el servicio de IA."
            }
        }
    }

    func generate(prompt: String, imageData: Data? = nil) async throws -> String {
        let prefs = PreferencesManager.shared
        
        switch prefs.preferredAIService {
        case .openai:
            guard prefs.openAIEnabled else { throw AIError.serviceDisabled }
            guard !prefs.openAIApiKey.isEmpty else { throw AIError.invalidAPIKey("OpenAI") }
            return try await OpenAIService.shared.generate(prompt: prompt, model: prefs.openAIDefaultModel, apiKey: prefs.openAIApiKey, isOpenRouter: false, imageData: imageData)
            
        case .openrouter:
            guard prefs.openRouterEnabled else { throw AIError.serviceDisabled }
            guard !prefs.openRouterAPIKey.isEmpty else { throw AIError.invalidAPIKey("OpenRouter") }
            return try await OpenAIService.shared.generate(prompt: prompt, model: prefs.openRouterDefaultModel, apiKey: prefs.openRouterAPIKey, isOpenRouter: true, imageData: imageData)
            
        case .gemini:
            guard prefs.geminiEnabled else { throw AIError.serviceDisabled }
            guard !prefs.geminiAPIKey.isEmpty else { throw AIError.invalidAPIKey("Google Gemini") }
            return try await GeminiService.shared.generate(prompt: prompt, model: prefs.geminiDefaultModel, imageData: imageData)
        }
    }
    
    // MARK: - Generación de Metadatos Comunes""",
    content,
    flags=re.DOTALL
)

with open('Promtier/Services/AIServiceManager.swift', 'w') as f:
    f.write(new_content)

