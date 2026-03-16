//
//  PromptServiceSimple.swift
//  Promtier
//
//  SERVICIO SIMPLIFICADO: Gestión de prompts en memoria (temporal)
//  Created by Carlos on 15/03/26.
//

import Foundation
import Combine

// SERVICIO SIMPLIFICADO: Gestión de prompts sin Core Data (para MVP)
class PromptServiceSimple: ObservableObject {
    private let clipboardService = ClipboardService.shared
    
    // CONFIGURABLE: Publicación de cambios para UI reactiva
    @Published var prompts: [Prompt] = []
    @Published var filteredPrompts: [Prompt] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observar cambios en búsqueda para filtrar automáticamente
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main) // CONFIGURABLE: Debounce de búsqueda
            .sink { [weak self] query in
                self?.filterPrompts(query: query)
            }
            .store(in: &cancellables)
        
        loadSampleData()
    }
    
    // MARK: - Operaciones CRUD
    
    /// Carga datos de ejemplo para demostración
    private func loadSampleData() {
        isLoading = true
        
        // CONFIGURABLE: Datos de ejemplo
        prompts = [
            Prompt(
                title: "Code Review",
                content: "Por favor, revisa este código y proporciona feedback constructivo sobre:\n\n1. Calidad del código\n2. Buenas prácticas\n3. Posibles mejoras\n4. Seguridad\n\nCódigo:\n{{codigo}}",
                description: "Plantilla para revisión de código",
                folder: "Trabajo"
            ),
            Prompt(
                title: "Blog Post Outline",
                content: "Crea un esquema para un blog post sobre {{tema}} con:\n\n- Título atractivo\n- Introducción\n- Puntos principales (3-5)\n- Conclusión\n- Call to action\n\nPúblico objetivo: {{audiencia}}",
                description: "Estructura para artículos de blog",
                folder: "Personal"
            ),
            Prompt(
                title: "Email Profesional",
                content: "Asunto: {{asunto}}\n\nEstimado/a {{nombre}},\n\n{{mensaje}}\n\nSaludos cordiales,\n{{firma}}",
                description: "Plantilla para emails profesionales",
                folder: "Trabajo"
            )
        ]
        
        // Marcar algunos como favoritos
        prompts[0].isFavorite = true
        prompts[1].isFavorite = true
        
        filterPrompts(query: searchQuery)
        isLoading = false
    }
    
    /// Crea un nuevo prompt
    func createPrompt(_ prompt: Prompt) -> Bool {
        // Verificar duplicados por título
        if prompts.contains(where: { $0.title.lowercased() == prompt.title.lowercased() }) {
            return false // CONFIGURABLE: Permitir duplicados o no
        }
        
        prompts.append(prompt)
        filterPrompts(query: searchQuery)
        return true
    }
    
    /// Actualiza un prompt existente
    func updatePrompt(_ prompt: Prompt) -> Bool {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else {
            return false
        }
        
        prompts[index] = prompt
        filterPrompts(query: searchQuery)
        return true
    }
    
    /// Elimina un prompt
    func deletePrompt(_ prompt: Prompt) -> Bool {
        prompts.removeAll { $0.id == prompt.id }
        filterPrompts(query: searchQuery)
        return true
    }
    
    // MARK: - Búsqueda y Filtrado
    
    /// Filtra prompts basado en consulta de búsqueda
    private func filterPrompts(query: String) {
        if query.isEmpty {
            filteredPrompts = prompts
            return
        }
        
        // CONFIGURABLE: Algoritmo de búsqueda simplificado
        let lowercaseQuery = query.lowercased()
        filteredPrompts = prompts.filter { prompt in
            prompt.title.lowercased().contains(lowercaseQuery) ||
            prompt.content.lowercased().contains(lowercaseQuery) ||
            (prompt.description?.lowercased().contains(lowercaseQuery) ?? false)
        }
        
        // CONFIGURABLE: Límite de resultados mostrados
        if filteredPrompts.count > 50 {
            filteredPrompts = Array(filteredPrompts.prefix(50))
        }
    }
    
    /// Obtiene prompts favoritos
    func getFavoritePrompts() -> [Prompt] {
        return prompts.filter { $0.isFavorite }
            .sorted { $0.useCount > $1.useCount }
    }
    
    /// Obtiene todos los prompts
    func getAllPrompts() -> [Prompt] {
        return prompts
    }
    
    /// Busca prompts por carpeta
    func getPromptsInFolder(_ folder: String) -> [Prompt] {
        return prompts.filter { $0.folder == folder }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    // MARK: - Operaciones de Uso
    
    /// Registra uso de prompt y lo copia al clipboard
    func usePrompt(_ prompt: Prompt) {
        // Incrementar contador de uso
        var updatedPrompt = prompt
        updatedPrompt.recordUse()
        
        _ = updatePrompt(updatedPrompt)
        
        // Copiar al clipboard
        clipboardService.copyToClipboard(prompt.content)
    }
    
    /// Copia prompt con variables de plantilla
    func usePromptWithVariables(_ prompt: Prompt, variables: [String: String]) {
        var processedContent = prompt.content
        
        // Reemplazar variables {{nombre}} con valores proporcionados
        for (key, value) in variables {
            processedContent = processedContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        // Copiar contenido procesado
        clipboardService.copyToClipboard(processedContent)
        
        // Registrar uso
        var updatedPrompt = prompt
        updatedPrompt.recordUse()
        _ = updatePrompt(updatedPrompt)
    }
    
    // MARK: - Estadísticas
    
    /// Obtiene prompts más usados
    func getMostUsedPrompts(limit: Int = 10) -> [Prompt] {
        return prompts.sorted { $0.useCount > $1.useCount }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Obtiene prompts recientemente modificados
    func getRecentlyModifiedPrompts(limit: Int = 10) -> [Prompt] {
        return prompts.sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Obtiene estadísticas generales
    func getStatistics() -> (total: Int, favorites: Int, totalUses: Int) {
        let total = prompts.count
        let favorites = prompts.filter { $0.isFavorite }.count
        let totalUses = prompts.reduce(0) { $0 + $1.useCount }
        
        return (total, favorites, totalUses)
    }
}
