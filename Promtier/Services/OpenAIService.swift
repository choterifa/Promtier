//
//  OpenAIService.swift
//  Promtier
//
//  SERVICIO: Comunicación con OpenAI API (GPT-4o, etc.)
//

import Foundation
import Combine

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
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
        
        // El manejo de streams de OpenAI (Server-Sent Events)
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                subject.send(completion: .finished)
                return
            }
            
            // OpenAI devuelve "data: {...}" por cada chunk
            let lines = responseString.components(separatedBy: "\n")
            for line in lines {
                guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
                
                let jsonString = String(line.dropFirst(6))
                if let jsonData = jsonString.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(OpenAIResponse.self, from: jsonData),
                   let content = chunk.choices.first?.delta?.content {
                    subject.send(content)
                }
            }
            
            subject.send(completion: .finished)
        }
        
        task.resume()
        return subject.eraseToAnyPublisher()
    }
}
