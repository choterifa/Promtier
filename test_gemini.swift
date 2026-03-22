import Foundation
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    struct GeminiContent: Codable { let parts: [GeminiPart] }
    struct GeminiPart: Codable { let text: String }
}
let body = GeminiRequest(contents: [
    GeminiRequest.GeminiContent(parts: [
        GeminiRequest.GeminiPart(text: "Hi")
    ])
])
let data = try! JSONEncoder().encode(body)
print(String(data: data, encoding: .utf8)!)
