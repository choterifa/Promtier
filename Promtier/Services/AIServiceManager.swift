//
//  AIServiceManager.swift
//  Promtier
//
//  SERVICIO: Enrutador unificado para los proveedores de IA
//

import Foundation

struct PromptMetadataResponse {
    let title: String
    let description: String
    let content: String
    let negativePrompt: String?
}

class AIServiceManager: AIServiceProtocol {
    static let shared = AIServiceManager()
    
    private init() {}
    
    // Almacena hasta cuándo está deshabilitado temporalmente un servicio por fallas o saturación
    private var cooldowns: [AIService: Date] = [:]
    private let cooldownDuration: TimeInterval = 10 * 60 // 10 minutos
    
    enum AIError: LocalizedError {
        case serviceDisabled
        case invalidAPIKey(String)
        case configurationError
        case allServicesFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .serviceDisabled: return "El servicio de IA seleccionado está desactivado en Preferencias."
            case .invalidAPIKey(let service): return "Falta la clave API para \(service)."
            case .configurationError: return "Error de configuración en el servicio de IA."
            case .allServicesFailed(let msg): return "Servicios saturados o fallaron: \(msg)"
            }
        }
    }
    
    // MARK: - UI Callbacks
    var onFallbackOccurred: ((String) -> Void)?
    
    private func reportFallback(service: AIService, error: String) {
        let serviceName = {
            switch service {
            case .openai: return "OpenAI"
            case .gemini: return "Gemini"
            case .openrouter: return "OpenRouter"
            }
        }()
        
        DispatchQueue.main.async {
            self.onFallbackOccurred?("⚠️ \(serviceName) falló (\(error)). Probando alternativa... (\(serviceName) desactivado temporalmente)")
        }
    }

    func generate(prompt: String, imageData: Data? = nil, useFallback: Bool = true) async throws -> String {
        let prefs = PreferencesManager.shared
        
        // Limpiar cooldowns expirados
        let now = Date()
        for (srv, expiration) in cooldowns {
            if now > expiration {
                cooldowns.removeValue(forKey: srv)
            }
        }
        
        // Define el orden de intento basado en la preferencia
        var allServicesToTry: [AIService] = [prefs.preferredAIService]
        
        if useFallback {
            let allServices: [AIService] = [.openai, .gemini, .openrouter]
            allServicesToTry += allServices.filter { $0 != prefs.preferredAIService }
        }
        
        // Filtrar servicios en cooldown
        var servicesToTry = allServicesToTry.filter { cooldowns[$0] == nil }
        
        // Si todos están en cooldown, intentamos el preferido de todas formas para no bloquear la app
        if servicesToTry.isEmpty {
            servicesToTry = [prefs.preferredAIService]
        }
        
        var lastError: Error?
        
        for service in servicesToTry {
            do {
                switch service {
                case .openai:
                    guard prefs.openAIEnabled, !prefs.openAIApiKey.isEmpty else { throw AIError.serviceDisabled }
                    return try await OpenAIService.shared.generate(prompt: prompt, model: prefs.openAIDefaultModel, apiKey: prefs.openAIApiKey, isOpenRouter: false, imageData: imageData)
                    
                case .openrouter:
                    guard prefs.openRouterEnabled, !prefs.openRouterAPIKey.isEmpty else { throw AIError.serviceDisabled }
                    return try await OpenAIService.shared.generate(prompt: prompt, model: prefs.openRouterDefaultModel, apiKey: prefs.openRouterAPIKey, isOpenRouter: true, imageData: imageData)
                    
                case .gemini:
                    guard prefs.geminiEnabled, !prefs.geminiAPIKey.isEmpty else { throw AIError.serviceDisabled }
                    return try await GeminiService.shared.generate(prompt: prompt, model: prefs.geminiDefaultModel, imageData: imageData)
                }
            } catch let error as AIError {
                if case .serviceDisabled = error { continue }
                lastError = error
            } catch let error as OpenAIAPIError {
                lastError = error
                // Si es un error de saturación o servidor, probamos el siguiente.
                let code = error.statusCode ?? 0
                if code == 429 || code >= 500 {
                    cooldowns[service] = Date().addingTimeInterval(cooldownDuration)
                    reportFallback(service: service, error: "\(code)")
                    print("⚠️ Fallback: \(service) falló por saturación (\(code)). Puesto en cooldown. Probando alternativa...")
                    continue
                }
            } catch let error as NSError {
                lastError = error
                if error.domain == "GeminiAPI" && (error.code == 429 || error.code >= 500) {
                    cooldowns[service] = Date().addingTimeInterval(cooldownDuration)
                    reportFallback(service: service, error: "\(error.code)")
                    print("⚠️ Fallback: Gemini falló por saturación (\(error.code)). Puesto en cooldown. Probando alternativa...")
                    continue
                }
                // Si es error de red o timeout, intentamos fallback
                if error.domain == NSURLErrorDomain {
                    cooldowns[service] = Date().addingTimeInterval(cooldownDuration)
                    reportFallback(service: service, error: "Red")
                    print("⚠️ Fallback: Error de red con \(service). Puesto en cooldown. Probando alternativa...")
                    continue
                }
            }
        }
        
        throw lastError ?? AIError.allServicesFailed("No hay servicios disponibles.")
    }
    
    // MARK: - Generación de Metadatos Comunes
    func generatePromptMetadata(title: String, content: String, keepContent: Bool = true) async throws -> PromptMetadataResponse {
        let isContentProvided = keepContent && !content.isEmpty
        let isTitleProvided = !title.isEmpty
        
        let titleInstruction = isTitleProvided
            ? "The title is already provided. DO NOT modify it in any way. Return it EXACTLY as it is."
            : "If the title is empty or generic, generate a catchy, short title (max 1 line)."

        let contentInstruction = isContentProvided
            ? "The content is already provided by the user. DO NOT modify it, do not expand it, and do not improve it. Return it EXACTLY as it is."
            : "Generate the main prompt content. It must be high-quality and detailed. Maintain EXISTING variables {{...}}. If you must create new variables, use a MAXIMUM of 3. New variables MUST use exact syntax {{snake_case_name}} (e.g. {{web_folder_path}}). NEVER USE ITALICS OR BOLD FORMATTING AROUND VARIABLES. For example, never output *{{variable}}* or _{{variable}}_, just output {{variable}} cleanly."

        let systemPrompt = """
        You are an expert prompt engineer. Your goal is to create or improve an AI prompt based on the user's input.
        
        INPUTS:
        - Title: \(title.isEmpty ? "No title provided" : title)
        - Content: \(content.isEmpty ? "No content provided" : content)
        
        INSTRUCTIONS:
        1. TITLE: \(titleInstruction)
        2. DESCRIPTION: Generate a concise description of what this prompt does (max 2 lines).
        3. CONTENT: \(contentInstruction)
        4. NEGATIVE PROMPT: Generate a list of practical things to AVOID for this prompt (e.g. "no formatting errors, no generic tone", etc).
        
        CRITICAL LANGUAGE RULE:
        - Detect the PRIMARY language of the user's input (title and content).
        - You MUST respond ENTIRELY in that SAME language. Every word of your response — title, description, content, negative prompt, variable names — must be in the input's language.
        
        RESPONSE FORMAT:
        Respond ONLY with the following format, using the pipe symbol (|) as separator:
        GeneratedTitle|GeneratedDescription|GeneratedContent|GeneratedNegativePrompt
        
        DO NOT include any other text, labels, or explanations. Just the FOUR parts separated by |.
        """
        
        let fullResponse = try await generate(prompt: systemPrompt)
        
        let parts = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
        if parts.count >= 4 {
            let neg = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
            return PromptMetadataResponse(
                title: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                description: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
                content: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
                negativePrompt: neg.isEmpty ? nil : neg
            )
        } else if parts.count >= 3 {
            return PromptMetadataResponse(
                title: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                description: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
                content: parts.dropFirst(2).joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines),
                negativePrompt: nil
            )
        } else if !fullResponse.contains("|") {
            // Fallback
            return PromptMetadataResponse(
                title: title.isEmpty ? "Prompt" : title,
                description: "Descripción generada automáticamente.",
                content: fullResponse.trimmingCharacters(in: .whitespacesAndNewlines),
                negativePrompt: nil
            )
        }
        
        throw URLError(.cannotParseResponse)
    }
}
