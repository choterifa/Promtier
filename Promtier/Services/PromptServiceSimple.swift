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
    @Published var selectedCategory: String? = nil
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
        
        // Observar cambios en categoría para filtrar automáticamente
        $selectedCategory
            .sink { [weak self] _ in
                self?.filterPrompts(query: self?.searchQuery ?? "")
            }
            .store(in: &cancellables)
        
        loadSampleData()
    }
    
    // MARK: - Operaciones CRUD
    
    /// Carga datos de ejemplo para demostración
    private func loadSampleData() {
        isLoading = true
        
        // CONFIGURABLE: Datos de ejemplo con categorías predefinidas
        prompts = [
            Prompt(
                title: "Poses para Modelos 3D",
                content: "Genera poses para modelos 3D con las siguientes características:\n\n- Estilo: {{estilo}}\n- Ángulo: {{angulo}}\n- Iluminación: {{iluminacion}}\n- Expresión: {{expresion}}\n\nDetalles adicionales: {{detalles}}",
                folder: "IA/Modelos"
            ),
            Prompt(
                title: "Función Python Optimizada",
                content: "Crea una función Python optimizada para {{funcionalidad}} con:\n\n- Parámetros: {{parametros}}\n- Retorno: {{retorno}}\n- Manejo de errores: {{errores}}\n- Documentación incluida",
                folder: "Código"
            ),
            Prompt(
                title: "Ideas para Contenido Creativo",
                content: "Genera ideas para contenido sobre {{tema}} dirigido a {{audiencia}}:\n\n- Formato: {{formato}}\n- Tono: {{tono}}\n- Longitud: {{longitud}}\n- Palabras clave: {{keywords}}",
                folder: "Creativo"
            ),
            Prompt(
                title: "Email Profesional",
                content: "Asunto: {{asunto}}\n\nEstimado/a {{nombre}},\n\n{{mensaje}}\n\nSaludos cordiales,\n{{firma}}",
                folder: "Trabajo"
            ),
            Prompt(
                title: "Resumen de Estudio",
                content: "Tema: {{tema}}\n\nConceptos clave:\n- {{concepto1}}\n- {{concepto2}}\n- {{concepto3}}\n\nEjemplos prácticos:\n{{ejemplos}}\n\nPreguntas de repaso:\n{{preguntas}}",
                folder: "Estudio"
            ),
            Prompt(
                title: "Recordatorio Personal",
                content: "Recordatorio para {{fecha}}:\n\nTarea: {{tarea}}\nPrioridad: {{prioridad}}\nNotas: {{notas}}",
                folder: "Personal"
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
    
    /// Filtra prompts basado en consulta de búsqueda y categoría seleccionada
    private func filterPrompts(query: String) {
        var filtered = prompts
        
        // Filtrar por categoría si hay una seleccionada
        if let category = selectedCategory {
            filtered = filtered.filter { $0.folder == category }
        }
        
        // Filtrar por texto si hay consulta
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            filtered = filtered.filter { prompt in
                prompt.title.lowercased().contains(lowercaseQuery) ||
                prompt.content.lowercased().contains(lowercaseQuery)
            }
        }
        
        // CONFIGURABLE: Límite de resultados mostrados
        if filtered.count > 50 {
            filtered = Array(filtered.prefix(50))
        }
        
        filteredPrompts = filtered
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
    
    /// Exporta todos los prompts a texto plano
    func exportAllPrompts() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        
        var exportText = "=== PROMPTS EXPORTADOS ===\n"
        exportText += "Fecha: \(timestamp)\n\n"
        
        for prompt in prompts {
            exportText += "Título: \(prompt.title)\n"
            exportText += "Contenido:\n\(prompt.content)\n"
            exportText += "---\n\n"
        }
        
        return exportText
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
