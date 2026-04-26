//
//  LocalModel.swift
//  Promtier
//
//  MODELO: Datos de un modelo local de IA descargable
//

import Foundation

struct LocalModel: Identifiable, Equatable {
    let id: String
    let name: String
    let developer: String
    let description: String
    let sizeString: String
    let sizeBytes: Int64
    let downloadURL: URL
    let speedRating: Int // 1 to 5
    let precisionRating: Int // 1 to 5
    let recommended: Bool
    
    // El nombre del archivo esperado en disco
    var filename: String {
        return downloadURL.lastPathComponent
    }
}

extension LocalModel {
    static let availableModels: [LocalModel] = [
        LocalModel(
            id: "llama-3.2-1b",
            name: "Llama 3.2 (1B)",
            developer: "Meta",
            description: "El modelo más rápido de Meta. Ideal para tareas ultra rápidas y borradores breves. Consume muy poca batería.",
            sizeString: "0.8 GB",
            sizeBytes: 800_000_000,
            downloadURL: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q6_K.gguf")!,
            speedRating: 5,
            precisionRating: 3,
            recommended: false
        ),
        LocalModel(
            id: "qwen-2.5-1.5b",
            name: "Qwen 2.5 (1.5B)",
            developer: "Alibaba",
            description: "Modelo ultraligero con el mejor entendimiento del español en su tamaño. Descarga rápida y respuesta casi instantánea.",
            sizeString: "1.1 GB",
            sizeBytes: 1_100_000_000,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!,
            speedRating: 5,
            precisionRating: 4,
            recommended: false
        ),
        LocalModel(
            id: "phi-3-mini",
            name: "Phi-3.5 Mini (3.8B)",
            developer: "Microsoft",
            description: "Equilibrio perfecto. Razonamiento lógico avanzado en un tamaño compacto. El modelo más equilibrado para Promtier.",
            sizeString: "2.3 GB",
            sizeBytes: 2_300_000_000,
            downloadURL: URL(string: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf")!,
            speedRating: 4,
            precisionRating: 4,
            recommended: true
        ),
        LocalModel(
            id: "gemma-2-2b",
            name: "Gemma 2 (2B)",
            developer: "Google",
            description: "Excelente para creatividad y redacción. Un modelo ligero pero muy capaz para mejorar prompts.",
            sizeString: "1.6 GB",
            sizeBytes: 1_600_000_000,
            downloadURL: URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!,
            speedRating: 4,
            precisionRating: 4,
            recommended: false
        ),
        LocalModel(
            id: "llama-3.1-8b",
            name: "Llama 3.1 (8B)",
            developer: "Meta",
            description: "Poder puro. Requiere 8GB+ de RAM. Ofrece la máxima precisión para reescritura compleja de prompts.",
            sizeString: "4.7 GB",
            sizeBytes: 4_700_000_000,
            downloadURL: URL(string: "https://huggingface.co/lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf")!,
            speedRating: 3,
            precisionRating: 5,
            recommended: false
        ),
        LocalModel(
            id: "mistral-7b-v0.3",
            name: "Mistral v0.3 (7B)",
            developer: "Mistral AI",
            description: "Un clásico muy confiable. Famoso por seguir instrucciones complejas con mucha fidelidad.",
            sizeString: "4.1 GB",
            sizeBytes: 4_100_000_000,
            downloadURL: URL(string: "https://huggingface.co/maziyarpanahi/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3.Q4_K_M.gguf")!,
            speedRating: 3,
            precisionRating: 5,
            recommended: false
        )
    ]
}
