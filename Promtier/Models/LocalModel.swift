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
            id: "phi-3-mini",
            name: "Phi-3 Mini (3.8B)",
            developer: "Microsoft",
            description: "Ideal como modelo de respaldo local. Extremadamente rápido y con excelente razonamiento lógico para su tamaño.",
            sizeString: "2.3 GB",
            sizeBytes: 2_300_000_000,
            downloadURL: URL(string: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf")!,
            speedRating: 5,
            precisionRating: 4,
            recommended: true
        ),
        LocalModel(
            id: "llama-3.1-8b",
            name: "Llama 3.1 (8B)",
            developer: "Meta",
            description: "El estándar de oro en modelos abiertos. Requiere más memoria RAM (8GB+ recomendados) pero ofrece respuestas muy precisas.",
            sizeString: "4.7 GB",
            sizeBytes: 4_700_000_000,
            downloadURL: URL(string: "https://huggingface.co/lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf")!,
            speedRating: 3,
            precisionRating: 5,
            recommended: false
        ),
        LocalModel(
            id: "qwen-2.5-1.5b",
            name: "Qwen 2.5 (1.5B)",
            developer: "Alibaba",
            description: "Modelo ultraligero con excelente entendimiento del español. Descarga rápida y respuesta casi instantánea.",
            sizeString: "1.2 GB",
            sizeBytes: 1_200_000_000,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!,
            speedRating: 5,
            precisionRating: 3,
            recommended: false
        )
    ]
}
