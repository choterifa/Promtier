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
        let text: String
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
    func generate(prompt: String, model: String) -> AnyPublisher<String, Error> {
        let apiKey = PreferencesManager.shared.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !apiKey.isEmpty else {
            return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
        }
        
        // Usamos generateContent en lugar de streamGenerateContent
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = GeminiRequest(contents: [
            GeminiRequest.GeminiContent(parts: [
                GeminiRequest.GeminiPart(text: prompt)
            ])
        ])
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        let subject = PassthroughSubject<String, Error>()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Error HTTP \(httpResponse.statusCode)"
                let nsError = NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                subject.send(completion: .failure(nsError))
                return
            }
            
            guard let data = data else {
                subject.send(completion: .finished)
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                if let text = decodedResponse.candidates?.first?.content?.parts?.first?.text {
                    subject.send(text)
                }
                subject.send(completion: .finished)
            } catch {
                let nsError = NSError(domain: "GeminiAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Error parseando respuesta: \(error.localizedDescription)"])
                subject.send(completion: .failure(nsError))
            }
        }
        
        task.resume()
        return subject.eraseToAnyPublisher()
    }
}
