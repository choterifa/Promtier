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
        "gpt-5.2",
        "gpt-5-mini",
        "gpt-5-nano",
        "gpt-5",
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "o3-mini",
        "o1",
        "o1-mini",
        "o4-mini",
        "gpt-4-turbo"
    ]

    /// Intenta obtener los modelos disponibles desde la cuenta (API Key).
    func listModelIDs(apiKey: String) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
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
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)

        // Filtrado simple: mostrar solo modelos de texto/chat razonables
        let allowedPrefixes = ["gpt-", "o1", "o3", "o4"]
        let ids = decoded.data
            .map { $0.id }
            .filter { id in allowedPrefixes.contains(where: { id.hasPrefix($0) }) }
            .sorted()
        return ids
    }
    
    /// Genera una respuesta basada en un prompt (Streaming soportado)
    func generate(prompt: String, model: String, apiKey: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that enhances and fixes AI prompts. Respond only with the improved prompt text."],
                ["role": "user", "content": prompt]
            ],
            "stream": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let subject = PassthroughSubject<String, Error>()
        
        // Handling OpenAI (Server-Sent Events)
        print("🚀 OpenAI Request: model=\(model)")
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI Network Error: \(error.localizedDescription)")
                subject.send(completion: .failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 OpenAI Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorMsg = String(data: data, encoding: .utf8) {
                        print("⚠️ OpenAI Error Body: \(errorMsg)")
                    }
                }
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                print("❓ OpenAI: No data received")
                subject.send(completion: .finished)
                return
            }
            
            // OpenAI returns "data: {...}" per chunk
            let lines = responseString.components(separatedBy: "\n")
            var hasFoundContent = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data: "), trimmed != "data: [DONE]" else { continue }
                
                let jsonString = String(trimmed.dropFirst(6))
                guard let jsonData = jsonString.data(using: .utf8) else { continue }

                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        if let chunk = try? JSONDecoder().decode(OpenAIResponse.self, from: jsonData) {
                            if let content = chunk.choices.first?.delta?.content {
                                subject.send(content)
                                hasFoundContent = true
                            } else if let content = chunk.choices.first?.message?.content {
                                // Non-streaming fallback
                                subject.send(content)
                                hasFoundContent = true
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.sync {
                        MainActor.assumeIsolated {
                            if let chunk = try? JSONDecoder().decode(OpenAIResponse.self, from: jsonData) {
                                if let content = chunk.choices.first?.delta?.content {
                                    subject.send(content)
                                    hasFoundContent = true
                                } else if let content = chunk.choices.first?.message?.content {
                                    // Non-streaming fallback
                                    subject.send(content)
                                    hasFoundContent = true
                                }
                            }
                        }
                    }
                }
            }
            
            if !hasFoundContent && (response as? HTTPURLResponse)?.statusCode == 200 {
                print("⚠️ OpenAI: No content chunks found in 200 OK response")
            }
            
            subject.send(completion: .finished)
        }
        
        task.resume()
        return subject.eraseToAnyPublisher()
    }
}
