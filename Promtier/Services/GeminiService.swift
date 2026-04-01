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
    
    /// Genera una respuesta basada en un prompt usando Google Gemini
    func generate(prompt: String, model: String, imageData: Data? = nil) async throws -> String {
        let apiKey = PreferencesManager.shared.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        
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
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decodedResponse.candidates?.first?.content?.parts?.first?.text else {
            throw NSError(domain: "GeminiAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida o vacía de Gemini"])
        }
        
        return text
    }
}
