//
//  OllamaService.swift
//  Promtier
//
//  SERVICIO: Comunicación con el servidor local de Ollama (IA Local)
//

import Foundation
import Combine

struct OllamaModel: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let modified_at: String?
    let size: Int64?
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaGenerateResponse: Codable {
    let model: String?
    let created_at: String?
    let response: String?
    let done: Bool?
}

class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    @Published var availableModels: [OllamaModel] = []
    @Published var isOllamaRunning: Bool = false
    @Published var selectedModel: String?
    
    private let baseURL = "http://localhost:11434"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkStatus()
        fetchModels()
    }
    
    /// Verifica si el servidor local de Ollama está activo
    func checkStatus() {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            DispatchQueue.main.async {
                self?.isOllamaRunning = (error == nil && (response as? HTTPURLResponse)?.statusCode == 200)
            }
        }.resume()
    }
    
    /// Obtiene la lista de modelos descargados por el usuario
    func fetchModels() {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: OllamaTagsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                self?.availableModels = response.models
                if self?.selectedModel == nil, let first = response.models.first {
                    self?.selectedModel = first.name
                }
            })
            .store(in: &cancellables)
    }
    
    /// Genera una respuesta basada en un prompt (Streaming opcional)
    func generate(prompt: String, model: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true // Usamos stream para mejor UX
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // El manejo de streams de línea por línea en URLSession requiere usar URLSessionDataDelegate
        // Para simplificar esta primera versión, devolveremos el stream como un Subject
        let subject = PassthroughSubject<String, Error>()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                subject.send(completion: .finished)
                return
            }
            
            // Procesar las múltiples líneas de JSON (formato NDJSON de Ollama)
            let lines = responseString.components(separatedBy: "\n").filter { !$0.isEmpty }
            for line in lines {
                if let lineData = line.data(using: .utf8),
                   let chunk = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: lineData) {
                    if let text = chunk.response {
                        subject.send(text)
                    }
                    if chunk.done == true {
                        subject.send(completion: .finished)
                    }
                }
            }
        }
        
        task.resume()
        return subject.eraseToAnyPublisher()
    }
}
