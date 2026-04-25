//
//  OllamaService.swift
//  Promtier
//
//  SERVICIO: Comunicación con Ollama local
//

import Foundation
import Combine

private struct OllamaTagsResponse: Codable {
    struct Model: Codable {
        let name: String
    }
    let models: [Model]
}

private struct OllamaChatRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
        let images: [String]?
    }
    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct OllamaChatResponse: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let message: Message?
    let done: Bool
    let error: String?
}

class OllamaService: ObservableObject {
    static let shared = OllamaService()
    
    private init() {}

    func listModelIDs(baseURL: String) async throws -> [String] {
        var host = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = "http://localhost:11434" }
        if !host.hasPrefix("http") { host = "http://" + host }
        
        guard let url = URL(string: "\(host)/api/tags") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { $0.name }.sorted()
    }

    func testConnection(baseURL: String) async throws -> Bool {
        var host = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = "http://localhost:11434" }
        if !host.hasPrefix("http") { host = "http://" + host }
        
        guard let url = URL(string: "\(host)/api/tags") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        }
        return false
    }

    func generate(prompt: String, model: String, baseURL: String, imageData: Data? = nil) async throws -> String {
        var host = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = "http://localhost:11434" }
        if !host.hasPrefix("http") { host = "http://" + host }
        
        guard let url = URL(string: "\(host)/api/chat") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var userImages: [String]? = nil
        if let imageData = imageData {
            userImages = [imageData.base64EncodedString()]
        }
        
        let reqBody = OllamaChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: "You are a helpful assistant that enhances and fixes AI prompts. Respond only with the improved prompt text. If an image is provided, describe it accurately to form a detailed prompt.", images: nil),
                .init(role: "user", content: prompt, images: userImages)
            ],
            stream: false
        )
        
        request.httpBody = try? JSONEncoder().encode(reqBody)
        
        print("🚀 Ollama Request: model=\(model)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("📡 Ollama Error Status Code: \(httpResponse.statusCode)")
            let rawBody = String(data: data, encoding: .utf8) ?? ""
            if !rawBody.isEmpty { print("⚠️ Ollama Error Body: \(rawBody)") }
            throw URLError(.badServerResponse)
        }
        
        let contentResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        if let err = contentResponse.error {
            throw NSError(domain: "OllamaError", code: 1, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        if let content = contentResponse.message?.content, !content.isEmpty {
            return content
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
}
