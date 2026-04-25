//
//  OpenAIService.swift
//  Promtier
//
//  SERVICIO: Comunicación con OpenAI API (GPT-4o, etc.)
//

import Foundation
import Combine

private struct OpenAIModelListResponse: Codable, Sendable {
    struct Model: Codable, Sendable {
        let id: String
    }

    let data: [Model]
}

private struct OpenAIErrorEnvelope: Codable, Sendable {
    struct OpenAIError: Codable, Sendable {
        let message: String?
        let type: String?
        let code: String?
    }

    let error: OpenAIError?
}

enum OpenAIAPIErrorKind: String, Sendable {
    case invalidAPIKey
    case modelNotFound
    case rateLimited
    case serverBusy
    case badRequest
    case emptyResponse
    case unknown
}

struct OpenAIAPIError: LocalizedError, Sendable {
    let kind: OpenAIAPIErrorKind
    let statusCode: Int?
    let message: String
    let code: String?
    let type: String?

    var errorDescription: String? {
        message
    }
}

struct OpenAIResponse: Codable, Sendable {
    struct Choice: Codable, Sendable {
        struct Message: Codable, Sendable {
            let content: String?
        }
        let message: Message?
        let delta: Message? // Usado en streaming
        let finish_reason: String?
    }
    let choices: [Choice]
}

class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}

    /// Lista de modelos sugeridos (curados). Se usa como fallback si no hay fetch dinámico.
    static let suggestedChatModels: [String] = [
        "gpt-4o",
        "gpt-4o-mini",
        "o3-mini",
        "o1",
        "o1-mini",
        "gpt-4-turbo"
    ]

    /// Intenta obtener los modelos disponibles desde la cuenta (API Key).
    func listModelIDs(apiKey: String, isOpenRouter: Bool = false) async throws -> [String] {
        let urlString = isOpenRouter ? "https://openrouter.ai/api/v1/models" : "https://api.openai.com/v1/models"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI/OpenRouter API Error: HTTP \(http.statusCode) - \(errorString)")
            }
            throw URLError(.badServerResponse)
        }

        do {
            let decoded = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)

            if isOpenRouter {
                let orModels = decoded.data.map { $0.id }.sorted()
                print("OpenRouter Models Fetched: \(orModels.count) valid models found.")
                return orModels
            }

            // Filtrado simple para OpenAI
            let allowedPrefixes = ["gpt-", "o1", "o3", "o4"]
            let ids = decoded.data
                .map { $0.id }
                .filter { id in allowedPrefixes.contains(where: { id.hasPrefix($0) }) }
                .sorted()
                
            print("OpenAI Models Fetched: \(ids.count) valid models found.")
            return ids
        } catch {
            print("Decode Error for OpenAI/OpenRouter models: \(error)")
            throw error
        }
    }
    
    /// Genera una respuesta basada en un prompt de forma asíncrona
    func testConnection(apiKey: String, isOpenRouter: Bool = false) async throws -> Bool {
        guard !apiKey.isEmpty else { return false }
        // Para OpenRouter o OpenAI, la simple lista de modelos valida la API Key
        let urlString = isOpenRouter ? "https://openrouter.ai/api/v1/models" : "https://api.openai.com/v1/models"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if isOpenRouter {
            request.addValue("Promtier App", forHTTPHeaderField: "HTTP-Referer")
        }
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        }
        return false
    }

    func generate(prompt: String, model: String, apiKey: String, isOpenRouter: Bool = false, imageData: Data? = nil) async throws -> String {
        let endpoint = isOpenRouter ? "https://openrouter.ai/api/v1/chat/completions" : "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if isOpenRouter {
            request.addValue("https://promtier.valencia", forHTTPHeaderField: "HTTP-Referer")
            request.addValue("Promtier", forHTTPHeaderField: "X-Title")
        }
        
        var userContent: Any = prompt
        if let imageData = imageData {
            let base64 = imageData.base64EncodedString()
            userContent = [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
            ]
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that enhances and fixes AI prompts. Respond only with the improved prompt text. If an image is provided, describe it accurately to form a detailed prompt."],
                ["role": "user", "content": userContent]
            ],
            "stream": false
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("🚀 OpenAI Request: model=\(model)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("📡 OpenAI Error Status Code: \(httpResponse.statusCode)")
            let rawBody = String(data: data, encoding: .utf8) ?? ""
            if !rawBody.isEmpty { print("⚠️ OpenAI Error Body: \(rawBody)") }
            
            var serverMessage = rawBody
            let decoded = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data)
            if let err = decoded?.error {
                serverMessage = err.message ?? serverMessage
            }
            
            let kind: OpenAIAPIErrorKind
            switch httpResponse.statusCode {
            case 400: kind = .badRequest
            case 401: kind = .invalidAPIKey
            case 404: kind = .modelNotFound
            case 429: kind = .rateLimited
            case 500, 502, 503, 504: kind = .serverBusy
            default: kind = .unknown
            }
            
            throw OpenAIAPIError(
                kind: kind,
                statusCode: httpResponse.statusCode,
                message: serverMessage.isEmpty ? "OpenAI HTTP \(httpResponse.statusCode)" : serverMessage,
                code: decoded?.error?.code,
                type: decoded?.error?.type
            )
        }
        
        let contentResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        if let content = contentResponse.choices.first?.message?.content, !content.isEmpty {
            return content
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
}
