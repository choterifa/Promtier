import re

with open('Promtier/Services/GeminiService.swift', 'r') as f:
    content = f.read()

# Look for testConnection, let's add listModelIDs right after it or modify it.
def replace_gemini(m):
    return """
    /// Obtiene la lista de modelos disponibles
    func listModelIDs(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            // Filter only gemini models
            return decoded.models.map { $0.name.replacingOccurrences(of: "models/", with: "") }.filter { $0.hasPrefix("gemini-") }.sorted()
        }
        throw URLError(.badServerResponse)
    }

    /// Verifica la conexión listando los modelos disponibles
""" + m.group(0)

content = re.sub(r'    /// Verifica la conexión listando los modelos disponibles\s*func testConnection\(apiKey: String\) async throws -> Bool \{', replace_gemini, content)

with open('Promtier/Services/GeminiService.swift', 'w') as f:
    f.write(content)

