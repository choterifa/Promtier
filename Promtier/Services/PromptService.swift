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
            switch category {
            case "Recientes":
                // Mostrar usados en las últimas 48 horas o los últimos 10
                let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 3600)
                filtered = filtered.filter { prompt in
                    if let lastUsed = prompt.lastUsedAt {
                        return lastUsed > fortyEightHoursAgo
                    }
                    return false
                }
                // Si hay pocos, rellenar con los más usados históricamente
                if filtered.count < 5 {
                    let mostUsed = prompts.sorted { $0.useCount > $1.useCount }.prefix(10)
                    for p in mostUsed {
                        if !filtered.contains(where: { $0.id == p.id }) {
                            filtered.append(p)
                        }
                    }
                }
                filtered.sort { ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast) }
                
            case "Sin categoría":
                filtered = filtered.filter { $0.folder == nil || $0.folder == "" }
            default:
                filtered = filtered.filter { $0.folder == category }
            }
        }
        
        // Filtrar por texto si hay consulta - Búsqueda Inteligente (Ponderada)
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            
            // Asignar puntuaciones para ordenación inteligente
            let scoredPrompts = filtered.map { prompt -> (Prompt, Int) in
                var score = 0
                let title = prompt.title.lowercased()
                let content = prompt.content.lowercased()
                
                if title == lowercaseQuery { score += 100 } // Coincidencia exacta título
                else if title.hasPrefix(lowercaseQuery) { score += 70 } // Empieza por
                else if title.contains(lowercaseQuery) { score += 50 } // Contiene
                
                if content.contains(lowercaseQuery) { score += 30 } // Contiene en cuerpo
                
                if let folder = prompt.folder?.lowercased(), folder.contains(lowercaseQuery) {
                    score += 20 // Coincidencia en categoría
                }
                
                return (prompt, score)
            }
            
            filtered = scoredPrompts
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
        }
        
        // CONFIGURABLE: Límite de resultados mostrados comentado para que se muestren todos en la categoría
        // if filtered.count > 50 {
        //    filtered = Array(filtered.prefix(50))
        // }
        
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
    
    /// Exporta todos los prompts en formato JSON (Copia de seguridad completa)
    func exportAllPromptsAsJSON() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(prompts)
        } catch {
            print("❌ Error codificando prompts a JSON: \(error)")
            return nil
        }
    }
    
    /// Importa prompts desde un archivo JSON
    func importPromptsFromData(_ data: Data) -> (success: Int, failed: Int) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedPrompts = try decoder.decode([Prompt].self, from: data)
            
            var successCount = 0
            var failedCount = 0
            
            for prompt in importedPrompts {
                // Comprobar si ya existe por ID para evitar duplicados exactos
                if prompts.contains(where: { $0.id == prompt.id }) {
                    failedCount += 1
                    continue
                }
                
                if createPrompt(prompt) {
                    successCount += 1
                } else {
                    failedCount += 1
                }
            }
            
            loadPrompts()
            return (successCount, failedCount)
        } catch {
            print("❌ Error decodificando archivo de importación: \(error)")
            return (0, 0)
        }
    }
    
    /// Restablece toda la base de datos (BORRADO TOTAL)
    func resetAllData() {
        let context = dataController.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PromptEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            dataController.save()
            loadPrompts()
            print("⚠️ Base de datos restablecida a cero")
        } catch {
            print("❌ Error al restablecer base de datos: \(error)")
        }
    }
    
    // MARK: - Operaciones de Uso
    
    /// Registra uso de prompt (contadores y fechas) sin copiar al clipboard
    func recordPromptUse(_ prompt: Prompt) {
        var updatedPrompt = prompt
        updatedPrompt.recordUse()
        _ = updatePrompt(updatedPrompt)
    }
    
    /// Registra uso de prompt y lo copia al clipboard (Versión estándar)
    func usePrompt(_ prompt: Prompt) {
        recordPromptUse(prompt)
        clipboardService.copyToClipboard(prompt.content)
    }
    
    /// Copia prompt con variables de plantilla (Legacy/Internal)
    func usePromptWithVariables(_ prompt: Prompt, variables: [String: String]) {
        var processedContent = prompt.content
        for (key, value) in variables {
            processedContent = processedContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        clipboardService.copyToClipboard(processedContent)
        recordPromptUse(prompt)
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
