import re

with open('Promtier/Services/GeminiService.swift', 'r') as f:
    content = f.read()

# Let's add better logging to GeminiService.swift generate method
def replace_gemini_generate(m):
    return """    func generate(prompt: String, model: String, imageData: Data? = nil) async throws -> String {
        let apiKey = PreferencesManager.shared.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\\(model):generateContent?key=\\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("Gemini Generate Request: \\(urlString)")
"""

content = re.sub(r'    func generate\(prompt: String, model: String, imageData: Data\? = nil\) async throws -> String \{\s+let apiKey = PreferencesManager\.shared\.geminiAPIKey\.trimmingCharacters\(in: \.whitespacesAndNewlines\)\s+guard !apiKey\.isEmpty else \{\s+throw URLError\(\.userAuthenticationRequired\)\s+\}\s+guard let url = URL\(string: "https://generativelanguage\.googleapis\.com/v1beta/models/\\\(model\):generateContent\?key=\\\(apiKey\)"\) else \{\s+throw URLError\(\.badURL\)\s+\}', replace_gemini_generate, content)

with open('Promtier/Services/GeminiService.swift', 'w') as f:
    f.write(content)

