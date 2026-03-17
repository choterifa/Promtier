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
    @Published var folders: [Folder] = []
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
            .sink { [weak self] category in
                self?.filterPrompts(query: self?.searchQuery ?? "", categoryOverride: category)
            }
            .store(in: &cancellables)
        
        seedDefaultFolders() // Crear categorías de sistema si no existen
        loadFolders()
        loadPrompts()
    }
    
    /// Crea las carpetas por defecto si no han sido sembradas aún en esta versión
    private func seedDefaultFolders() {
        let context = dataController.viewContext
        
        // Usamos un flag de versión para asegurar que se siembren al menos una vez al actualizar
        let seedKey = "hasSeededDefaultsV21"
        if UserDefaults.standard.bool(forKey: seedKey) { return }
        
        let request = FolderEntity.fetchAll(in: context)
        
        do {
            let entities = try context.fetch(request)
            let existingNames = entities.map { $0.name }
            
            print("🌱 Sembrando categorías base como guía...")
            var seededCount = 0
            
            for cat in PredefinedCategory.allCases {
                // Solo añadir si no existe ya una con ese nombre exacto
                if !existingNames.contains(cat.displayName) {
                    let folder = Folder(
                        id: UUID(),
                        name: cat.displayName,
                        color: cat.hexColor,
                        icon: cat.icon,
                        createdAt: Date(),
                        parentId: nil
                    )
                    _ = FolderEntity.create(from: folder, in: context)
                    seededCount += 1
                }
            }
            
            if seededCount > 0 {
                dataController.save()
                print("✅ \(seededCount) categorías base añadidas.")
            }
            
            UserDefaults.standard.set(true, forKey: seedKey)
            
        } catch {
            print("Error sembrando categorías: \(error)")
        }
    }
    
    // MARK: - Operaciones CRUD
    
    /// Carga todos los prompts desde Core Data
    func loadPrompts() {
        DispatchQueue.main.async { self.isLoading = true }
        
        let request = PromptEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            let loadedPrompts = entities.map { $0.toPrompt() }
            
            DispatchQueue.main.async {
                self.prompts = loadedPrompts
                self.filterPrompts(query: self.searchQuery)
                self.isLoading = false
            }
        } catch {
            print("Error cargando prompts: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    /// Carga todas las carpetas desde Core Data
    func loadFolders() {
        let request = FolderEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            let loadedFolders = entities.map { $0.toFolder() }
            
            DispatchQueue.main.async {
                self.folders = loadedFolders
            }
        } catch {
            print("Error cargando carpetas: \(error)")
        }
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
    
    // MARK: - Operaciones de Carpetas
    
    /// Crea una nueva carpeta
    func createFolder(_ folder: Folder) -> Bool {
        let context = dataController.viewContext
        _ = FolderEntity.create(from: folder, in: context)
        dataController.save()
        loadFolders()
        return true
    }
    
    /// Actualiza una carpeta existente
    func updateFolder(_ folder: Folder, oldName: String? = nil) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.updateFromFolder(folder)
                
                // Si el nombre cambió, actualizar todos los prompts asociados
                if let oldName = oldName, oldName != folder.name {
                    let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    promptRequest.predicate = NSPredicate(format: "folder == %@", oldName)
                    
                    let promptEntities = try context.fetch(promptRequest)
                    for promptEntity in promptEntities {
                        promptEntity.folder = folder.name
                    }
                }
                
                dataController.save()
                loadFolders()
                loadPrompts()
                return true
            }
        } catch {
            print("Error actualizando carpeta: \(error)")
        }
        
        return false
    }
    
    /// Elimina una carpeta
    func deleteFolder(_ folder: Folder) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                // Desasociar prompts antes de borrar la carpeta
                let promptRequest: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                promptRequest.predicate = NSPredicate(format: "folder == %@", folder.name)
                
                let promptEntities = try context.fetch(promptRequest)
                for promptEntity in promptEntities {
                    promptEntity.folder = nil
                }
                
                context.delete(entity)
                dataController.save()
                loadFolders()
                loadPrompts()
                return true
            }
        } catch {
            print("Error eliminando carpeta: \(error)")
        }
        
        return false
    }
    
    // MARK: - Búsqueda y Filtrado
    
    /// Filtra prompts basado en consulta de búsqueda y categoría seleccionada
    private func filterPrompts(query: String, categoryOverride: String? = "USE_CURRENT") {
        var filtered = prompts
        
        // Determinar qué categoría usar (la del override o la actual)
        let category: String?
        if let override = categoryOverride, override == "USE_CURRENT" {
            category = selectedCategory
        } else {
            category = categoryOverride
        }
        
        // Filtrar por categoría si hay una seleccionada
        if let category = category {
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
                
            case "Favoritos":
                filtered = filtered.filter { $0.isFavorite }
                filtered.sort { $0.useCount > $1.useCount }
                
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
    
    /// Exporta toda la base de datos (Prompts + Carpetas) en formato JSON
    func exportAllPromptsAsJSON() -> Data? {
        do {
            let package = BackupPackage(
                version: "2.1",
                prompts: prompts,
                folders: folders
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(package)
        } catch {
            print("❌ Error codificando backup a JSON: \(error)")
            return nil
        }
    }
    
    /// Exporta todos los prompts en formato CSV (RFC 4180)
    /// Columnas: id, title, content, folder, icon, isFavorite, useCount, createdAt, modifiedAt
    func exportAllPromptsAsCSV() -> Data? {
        let iso = ISO8601DateFormatter()
        
        // Función helper: envuelve el valor en comillas y escapa las comillas internas
        func csv(_ value: String) -> String {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        
        var rows: [String] = []
        // Cabecera
        rows.append("id,title,content,folder,icon,isFavorite,useCount,createdAt,modifiedAt")
        
        for p in prompts {
            let row = [
                csv(p.id.uuidString),
                csv(p.title),
                csv(p.content),
                csv(p.folder ?? ""),
                csv(p.icon ?? ""),
                p.isFavorite ? "true" : "false",
                "\(p.useCount)",
                csv(iso.string(from: p.createdAt)),
                csv(iso.string(from: p.modifiedAt))
            ].joined(separator: ",")
            rows.append(row)
        }
        
        let csvString = rows.joined(separator: "\n")
        return csvString.data(using: .utf8)
    }
    
    /// Importa datos desde un archivo JSON (Soporta formato antiguo y nuevo BackupPackage)
    func importPromptsFromData(_ data: Data) -> (success: Int, failed: Int, foldersCreated: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var promptsToImport: [Prompt] = []
        var foldersToImport: [Folder] = []
        var foldersCreated = 0
        
        do {
            // Intentar decodificar como BackupPackage (Nuevo Formato)
            let package = try decoder.decode(BackupPackage.self, from: data)
            promptsToImport = package.prompts
            foldersToImport = package.folders
            print("📦 Detectado formato BackupPackage v\(package.version)")
        } catch {
            // Intentar decodificar como [Prompt] (Formato Antiguo)
            do {
                promptsToImport = try decoder.decode([Prompt].self, from: data)
                print("📄 Detectado formato de lista de prompts (Legacy)")
            } catch {
                print("❌ Error decodificando archivo de importación: \(error)")
                return (0, 0, 0)
            }
        }
        
        // Detectar Carpetas
        for folder in foldersToImport {
            // Evitar duplicados por nombre o ID
            if !folders.contains(where: { $0.id == folder.id || $0.name == folder.name }) {
                if createFolder(folder) {
                    foldersCreated += 1
                }
            }
        }
        
        // 2. Importar Prompts
        var successCount = 0
        var failedCount = 0
        
        for prompt in promptsToImport {
            // Evitar duplicados exactos por ID
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
        
        loadFolders()
        loadPrompts()
        return (successCount, failedCount, foldersCreated)
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

// MARK: - Estructuras de Soporte para Transferencia

/// Paquete completo de copia de seguridad
struct BackupPackage: Codable {
    var version: String
    var prompts: [Prompt]
    var folders: [Folder]
}
