//
//  LocalLLMService.swift
//  Promtier
//
//  SERVICIO: Ejecución de modelos locales (llama.cpp)
//

import Foundation

#if canImport(LlamaSwift)
import LlamaSwift
#endif

class LocalLLMService {
    static let shared = LocalLLMService()
    
    private init() {}
    
    /// Genera una respuesta usando el modelo local almacenado en `modelUrl`
    func generate(prompt: String, modelUrl: URL) async throws -> String {
        #if canImport(LlamaSwift)
        
        // --- CÓDIGO REAL DE LLAMA.CPP ---
        // Este bloque se activará cuando instales el Swift Package de llama.cpp
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Configuración básica del contexto (simulada basada en la API de LlamaContext)
                var params = llama_context_default_params()
                params.n_ctx = 4096 // Contexto
                
                var modelParams = llama_model_default_params()
                modelParams.n_gpu_layers = 99 // Para usar Metal en Apple Silicon
                
                guard let model = llama_load_model_from_file(modelUrl.path.cString(using: .utf8), modelParams) else {
                    continuation.resume(throwing: NSError(domain: "LocalLLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo cargar el modelo"]))
                    return
                }
                
                guard let context = llama_new_context_with_model(model, params) else {
                    llama_free_model(model)
                    continuation.resume(throwing: NSError(domain: "LocalLLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo inicializar el contexto"]))
                    return
                }
                
                // --- BUCLE DE INFERENCIA DE LLAMA.CPP ---
                llama_backend_init()
                
                // Preparar tokens (estimando tamaño)
                let n_prompt_max = Int32(4096)
                var prompt_tokens = [llama_token](repeating: 0, count: Int(n_prompt_max))
                let vocab = llama_model_get_vocab(model)
                let n_prompt = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &prompt_tokens, n_prompt_max, true, true)
                
                if n_prompt < 0 {
                    llama_free(context)
                    llama_free_model(model)
                    llama_backend_free()
                    continuation.resume(throwing: NSError(domain: "LocalLLM", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error tokenizando"]))
                    return
                }
                
                // Función auxiliar local para el batch
                func add_to_batch(_ b: inout llama_batch, _ t: llama_token, _ p: llama_pos, _ seq: [llama_seq_id], _ logits: Bool) {
                    let idx = Int(b.n_tokens)
                    b.token[idx] = t
                    b.pos[idx] = p
                    b.n_seq_id[idx] = Int32(seq.count)
                    for (i, s) in seq.enumerated() {
                        b.seq_id[idx]![i] = s
                    }
                    b.logits[idx] = logits ? 1 : 0
                    b.n_tokens += 1
                }
                
                // Inicializar batch
                var batch = llama_batch_init(n_prompt, 0, 1)
                for i in 0..<Int(n_prompt) {
                    add_to_batch(&batch, prompt_tokens[i], Int32(i), [0], false)
                }
                batch.logits[Int(n_prompt) - 1] = 1 // Queremos logits del último token
                
                if llama_decode(context, batch) != 0 {
                    llama_batch_free(batch)
                    llama_free(context)
                    llama_free_model(model)
                    llama_backend_free()
                    continuation.resume(throwing: NSError(domain: "LocalLLM", code: 4, userInfo: [NSLocalizedDescriptionKey: "Error decodificando"]))
                    return
                }
                
                // Inicializar sampler simple (Greedy)
                let sampler = llama_sampler_init_greedy()
                
                var responseStr = ""
                var n_cur = n_prompt
                let n_predict = Int32(128) // Límite para no colgar eternamente
                
                while n_cur < n_prompt + n_predict {
                    let new_token_id = llama_sampler_sample(sampler, context, -1)
                    
                    if llama_vocab_is_eog(vocab, new_token_id) {
                        break
                    }
                    
                    // Convertir a string
                    var buf = [CChar](repeating: 0, count: 16)
                    let n_chars = llama_token_to_piece(vocab, new_token_id, &buf, Int32(buf.count), 0, false)
                    if n_chars > 0 {
                        let str = String(cString: buf)
                        responseStr += str
                    }
                    
                    // Preparar siguiente decode
                    batch.n_tokens = 0
                    add_to_batch(&batch, new_token_id, n_cur, [0], true)
                    
                    if llama_decode(context, batch) != 0 {
                        break
                    }
                    
                    n_cur += 1
                }
                
                llama_sampler_free(sampler)
                llama_batch_free(batch)
                llama_free(context)
                llama_free_model(model)
                llama_backend_free()
                
                continuation.resume(returning: responseStr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        #else
        
        // --- SIMULACIÓN HASTA AÑADIR LA DEPENDENCIA ---
        print("🚀 [LocalLLMService] Iniciando generación local usando: \(modelUrl.lastPathComponent)")
        print("⚠️ [LocalLLMService] llama.cpp SPM no está importado. Simulando respuesta local...")
        
        try await Task.sleep(nanoseconds: 2_500_000_000) // Simular 2.5s de procesamiento
        
        let promptPreview = prompt.count > 30 ? String(prompt.prefix(30)) + "..." : prompt
        
        return """
        [RESPUESTA GENERADA LOCALMENTE]
        Esta es una respuesta rápida de respaldo procesada internamente.
        
        El modelo cargado fue: \(modelUrl.lastPathComponent)
        Prompt original: \(promptPreview)
        
        (Nota para el desarrollador: Añade el Swift Package de llama.cpp para ejecutar la inferencia real).
        """
        
        #endif
    }
}
