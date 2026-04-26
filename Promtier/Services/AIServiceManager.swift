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
    
    enum AIError: LocalizedError {
        case serviceDisabled
        case invalidAPIKey(String)
        case invalidModel(String)
        case configurationError
        
        var errorDescription: String? {
            switch self {
            case .serviceDisabled: return "El servicio de IA seleccionado está desactivado en Preferencias."
            case .invalidAPIKey(let service): return "Falta la clave API para \(service)."
            case .invalidModel(let service): return "Falta configurar el modelo para \(service)."
            case .configurationError: return "Error de configuración en el servicio de IA."
            }
        }
    }

    func generate(prompt: String, imageData: Data? = nil) async throws -> String {
        let prefs = PreferencesManager.shared
        
        do {
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
                
            case .ollama:
                guard prefs.ollamaEnabled else { throw AIError.serviceDisabled }
                let model = prefs.ollamaDefaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !model.isEmpty else { throw AIError.invalidModel("Ollama") }
                return try await OllamaService.shared.generate(prompt: prompt, model: model, baseURL: prefs.ollamaBaseURL, imageData: imageData)
            }
        } catch {
            // FALLBACK A MODELO LOCAL
            if prefs.localFallbackEnabled, 
               let fallbackModel = LocalModelDownloadManager.shared.getBestDownloadedModel() {
                print("⚠️ [AIServiceManager] Error con API remota: \(error.localizedDescription). Iniciando Fallback Local...")
                
                let modelURL = LocalModelDownloadManager.shared.modelsDirectoryURL.appendingPathComponent(fallbackModel.filename)
                
                // Disparamos una notificación para que la UI pueda mostrar un indicador visual si lo desea
                NotificationCenter.default.post(name: NSNotification.Name("didFallbackToLocalModel"), object: fallbackModel.name)
                
                return try await LocalLLMService.shared.generate(prompt: prompt, modelUrl: modelURL)
            }
            
            throw error
        }
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
