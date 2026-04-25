//
//  GeminiService.swift
//  Promtier
//
//  SERVICIO: Comunicación con el API de Google Gemini
//

import Foundation
import Combine

struct GeminiRequest: Codable, Sendable {
    let contents: [GeminiContent]
    
    struct GeminiContent: Codable, Sendable {
        let parts: [GeminiPart]
    }
    
    struct GeminiPart: Codable, Sendable {
        let text: String?
        let inlineData: GeminiInlineData?
    }
    
    struct GeminiInlineData: Codable, Sendable {
        let mimeType: String
        let data: String
    }
}

struct GeminiResponse: Codable, Sendable {
    let candidates: [GeminiCandidate]?
    
    struct GeminiCandidate: Codable, Sendable {
        let content: GeminiContent?
    }
    
    struct GeminiContent: Codable, Sendable {
        let parts: [GeminiPart]?
    }
    
    struct GeminiPart: Codable, Sendable {
        let text: String?
    }
}

class GeminiService: ObservableObject {
    static let shared = GeminiService()
    
    private init() {}
    
    struct GeminiModelsResponse: Codable, Sendable {
        struct Model: Codable, Sendable {
            let name: String
            let supportedGenerationMethods: [String]?
        }
        let models: [Model]
    }


    /// Obtiene la lista de modelos disponibles
    func listModelIDs(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            do {
                let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
                let validModels = decoded.models.filter { model in
                    let methods = model.supportedGenerationMethods ?? []
                    return methods.contains("generateContent")
                }.map { $0.name.replacingOccurrences(of: "models/", with: "") }
                 .filter { $0.hasPrefix("gemini-") }
                 .sorted()
                 
                print("Gemini Models Fetched: \(validModels.count) valid models found.")
                for model in validModels {
                    print(" - \(model)")
                }
                
                return validModels
            } catch {
                print("Gemini Decode Error: \(error)")
                throw error
            }
        }
        if let httpResponse = response as? HTTPURLResponse {
            print("Gemini API Error: HTTP \(httpResponse.statusCode)")
        }
        if let errorString = String(data: data, encoding: .utf8) {
            print("Gemini API Response Data: \(errorString)")
        }
        throw URLError(.badServerResponse)
    }

    /// Verifica la conexión listando los modelos disponibles
    /// Verifica la conexión listando los modelos disponibles
    func testConnection(apiKey: String) async throws -> Bool {
        guard !apiKey.isEmpty else { return false }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            _ = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            return true
        }
        return false
    }

    /// Genera una respuesta basada en un prompt usando Google Gemini
    func generate(prompt: String, model: String, imageData: Data? = nil) async throws -> String {
        let apiKey = PreferencesManager.shared.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("Gemini Generate Request: \(urlString)")

        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var parts: [GeminiRequest.GeminiPart] = []
        parts.append(GeminiRequest.GeminiPart(text: prompt, inlineData: nil))
        
        if let imageData = imageData {
            parts.append(GeminiRequest.GeminiPart(text: nil, inlineData: GeminiRequest.GeminiInlineData(mimeType: "image/jpeg", data: imageData.base64EncodedString())))
        }
        
        let body = GeminiRequest(contents: [
            GeminiRequest.GeminiContent(parts: parts)
        ])
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Error HTTP \(httpResponse.statusCode)"
            print("❌ Gemini API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decodedResponse.candidates?.first?.content?.parts?.first?.text else {
            throw NSError(domain: "GeminiAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida o vacía de Gemini"])
        }
        
        return text
    }
}
