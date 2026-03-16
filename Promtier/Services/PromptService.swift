//
//  PromptService.swift
//  Promtier
//
//  SERVICIO PRINCIPAL: CRUD, búsqueda y gestión de prompts
//  Created by Carlos on 15/03/26.
//

import Foundation
import CoreData
import Combine

// SERVICIO PRINCIPAL: Gestión completa de prompts
class PromptService: ObservableObject {
    private let dataController = DataController.shared
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
        
        loadPrompts()
    }
    
    // MARK: - Operaciones CRUD
    
    /// Carga todos los prompts desde Core Data
    func loadPrompts() {
        isLoading = true
        
        let request = PromptEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            prompts = entities.map { $0.toPrompt() }
            filterPrompts(query: searchQuery)
        } catch {
            // CONFIGURABLE: Manejo de error de carga
            print("Error cargando prompts: \(error)")
        }
        
        isLoading = false
    }
    
    /// Crea un nuevo prompt
    func createPrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        
        // Verificar duplicados por título
        if prompts.contains(where: { $0.title.lowercased() == prompt.title.lowercased() }) {
            return false // CONFIGURABLE: Permitir duplicados o no
        }
        
        _ = PromptEntity.create(from: prompt, in: context)
        dataController.save()
        
        loadPrompts()
        return true
    }
    
    /// Actualiza un prompt existente
    func updatePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.updateFromPrompt(prompt)
                dataController.save()
                loadPrompts()
                return true
            }
        } catch {
            print("Error actualizando prompt: \(error)")
        }
        
        return false
    }
    
    /// Elimina un prompt
    func deletePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                context.delete(entity)
                dataController.save()
                loadPrompts()
                return true
            }
        } catch {
            print("Error eliminando prompt: \(error)")
        }
        
        return false
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
    
    /// Busca prompts por carpeta
    func getPromptsInFolder(_ folder: String) -> [Prompt] {
        return prompts.filter { $0.folder == folder }
            .sorted { $0.modifiedAt > $1.modifiedAt }
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
