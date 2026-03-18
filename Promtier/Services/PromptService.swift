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
    @Published var trashedPrompts: [Prompt] = []
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
                // VALIDACIÓN: Limitar a 40 caracteres
                if query.count > 40 {
                    self?.searchQuery = String(query.prefix(40))
                }
                self?.filterPrompts(query: self?.searchQuery ?? "")
            }
            .store(in: &cancellables)
            
        // Observar cambios en categoría para filtrar automáticamente
        $selectedCategory
            .sink { [weak self] category in
                self?.filterPrompts(query: self?.searchQuery ?? "", categoryOverride: category)
            }
            .store(in: &cancellables)
        
        seedDefaultFolders() // Crear categorías de sistema si no existen
        seedDefaultPrompts() // Crear prompts de ejemplo iniciales
        purgeExpiredTrash()  // Limpiar papelera de entradas > 7 días
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
    
    /// Crea prompts de ejemplo para guiar al usuario
    private func seedDefaultPrompts() {
        let context = dataController.viewContext
        let seedKey = "hasSeededInitialPromptsV22" // BUMP VERSION
        if UserDefaults.standard.bool(forKey: seedKey) { return }
        
        print("🌱 Sembrando prompts de ejemplo (V22)...")
        
        // 1. Prompt Normal (Email) con Snippet de firma
        let language = PreferencesManager.shared.language
        let emailPrompt = Prompt(
            title: "default_prompt_email_title".localized(for: language),
            content: "default_prompt_email_content".localized(for: language),
            folder: PredefinedCategory.work.displayName,
            icon: "briefcase.fill"
        )
        _ = PromptEntity.create(from: emailPrompt, in: context)
        
        // 2. Prompt con Variables (Programación)
        let codingPrompt = Prompt(
            title: "default_prompt_coding_title".localized(for: language),
            content: "default_prompt_coding_content".localized(for: language),
            folder: PredefinedCategory.code.displayName,
            icon: "terminal.fill"
        )
        _ = PromptEntity.create(from: codingPrompt, in: context)
        
        // 3. Prompt de Diseño (Creativo) con IMAGEN
        let imagePath = "/Users/valencia/.gemini/antigravity/brain/834ebcad-97e6-4d5e-a810-2da61e58cece/cyberpunk_example_result_1773778750439.png"
        var showcaseImages: [Data] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) {
            showcaseImages.append(data)
        }
        
        let creativePrompt = Prompt(
            title: "default_prompt_creative_title".localized(for: language),
            content: "A stunning cyberpunk cityscape at night, neon purple and blue lights, high detail, 8k resolution, cinematic lighting.",
            folder: PredefinedCategory.creative.displayName,
            icon: "sparkles",
            showcaseImages: showcaseImages
        )
        _ = PromptEntity.create(from: creativePrompt, in: context)
        
        dataController.save()
        UserDefaults.standard.set(true, forKey: seedKey)
        self.loadPrompts() // Recargar para que aparezcan inmediatamente
        print("✅ Prompts de ejemplo actualizados.")
    }
    
    // MARK: - Operaciones CRUD
    
    /// Carga todos los prompts desde Core Data (excluye los de la papelera)
    func loadPrompts() {
        DispatchQueue.main.async { self.isLoading = true }
        
        let request = PromptEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            let allPrompts = entities.map { $0.toPrompt() }
            
            DispatchQueue.main.async {
                // Separar prompts activos de los eliminados
                self.prompts = allPrompts.filter { !$0.isInTrash }
                self.trashedPrompts = allPrompts.filter { $0.isInTrash }.sorted {
                    ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
                }
                self.filterPrompts(query: self.searchQuery)
                self.isLoading = false
            }
        } catch {
            print("Error cargando prompts: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    /// Carga todas las carpetas desde Core Data aplicando el orden guardado
    func loadFolders() {
        let request = FolderEntity.fetchAll(in: dataController.viewContext)
        
        do {
            let entities = try dataController.viewContext.fetch(request)
            var loadedFolders = entities.map { $0.toFolder() }
            
            // Aplicar orden personalizado guardado en UserDefaults
            if let savedOrder = UserDefaults.standard.stringArray(forKey: "folderSortOrder") {
                loadedFolders.sort { folder1, folder2 in
                    let index1 = savedOrder.firstIndex(of: folder1.id.uuidString) ?? Int.max
                    let index2 = savedOrder.firstIndex(of: folder2.id.uuidString) ?? Int.max
                    
                    if index1 != index2 {
                        return index1 < index2
                    }
                    return folder1.name < folder2.name // Backup order
                }
            }
            
            DispatchQueue.main.async {
                self.folders = loadedFolders
            }
        } catch {
            print("Error cargando carpetas: \(error)")
        }
    }
    
    /// Persiste un nuevo orden de carpetas
    func reorderFolders(_ folders: [Folder]) {
        let order = folders.map { $0.id.uuidString }
        UserDefaults.standard.set(order, forKey: "folderSortOrder")
        
        DispatchQueue.main.async {
            self.folders = folders
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
    
    // MARK: - Papelera (Soft Delete)
    
    /// Mueve prompt a la papelera (soft delete)
    func deletePrompt(_ prompt: Prompt) -> Bool {
        var trashed = prompt
        trashed.deletedAt = Date()
        return updatePrompt(trashed)
    }
    
    /// Restaura un prompt desde la papelera
    func restorePrompt(_ prompt: Prompt) -> Bool {
        var restored = prompt
        restored.deletedAt = nil
        return updatePrompt(restored)
    }
    
    /// Elimina un prompt permanentemente de CoreData
    func permanentlyDeletePrompt(_ prompt: Prompt) -> Bool {
        let context = dataController.viewContext
        let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prompt.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                // Limpiar también el UserDefaults del trash
                var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
                dict.removeValue(forKey: prompt.id.uuidString)
                UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
                
                context.delete(entity)
                dataController.save()
                loadPrompts()
                return true
            }
        } catch {
            print("Error eliminando prompt permanentemente: \(error)")
        }
        return false
    }
    
    /// Elimina todos los prompts de la papelera de forma permanente
    func emptyTrash() {
        for prompt in trashedPrompts {
            _ = permanentlyDeletePrompt(prompt)
        }
    }
    
    /// Elimina automáticamente los prompts con más de 7 días de eliminación
    private func purgeExpiredTrash() {
        let context = dataController.viewContext
        let request = PromptEntity.fetchAll(in: context)
        
        guard let entities = try? context.fetch(request) else { return }
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        
        var purgedCount = 0
        for entity in entities {
            if let deletedAt = entity.deletedAt, deletedAt < cutoff {
                // Limpiar UserDefaults
                var dict = UserDefaults.standard.dictionary(forKey: PromptEntity.trashKey) as? [String: Date] ?? [:]
                dict.removeValue(forKey: entity.id.uuidString)
                UserDefaults.standard.set(dict, forKey: PromptEntity.trashKey)
                context.delete(entity)
                purgedCount += 1
            }
        }
        if purgedCount > 0 {
            dataController.save()
            print("🗑️ Purgados \(purgedCount) prompts expirados de la papelera.")
        }
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
            case "recent":
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
                
            case "favorites":
                filtered = filtered.filter { $0.isFavorite }
                filtered.sort { $0.useCount > $1.useCount }
                
            case "uncategorized":
                filtered = filtered.filter { $0.folder == nil || $0.folder == "" }
            default:
                filtered = filtered.filter { $0.folder == category }
            }
        }
        
        // Filtrar por texto si hay consulta - MOTOR DE BÚSQUEDA AVANZADO (Fuzzy + Phrasal + Weighted)
        if !query.isEmpty {
            let originalQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !originalQuery.isEmpty else { 
                filteredPrompts = filtered
                return 
            }
            
            // 1. EXTRAER FRASES EXACTAS (entre comillas)
            var phrasalQueries: [String] = []
            var remainingQuery = originalQuery
            
            let regex = try? NSRegularExpression(pattern: "\"([^\"]+)\"", options: [])
            if let matches = regex?.matches(in: originalQuery, options: [], range: NSRange(originalQuery.startIndex..., in: originalQuery)) {
                for match in matches.reversed() { // Reversa para no corromper índices al remover
                    if let range = Range(match.range(at: 1), in: originalQuery) {
                        phrasalQueries.append(originalQuery[range].lowercased())
                    }
                    if let fullRange = Range(match.range(at: 0), in: originalQuery) {
                        remainingQuery.removeSubrange(fullRange)
                    }
                }
            }
            
            // 2. NORMALIZACIÓN Y KEYWORDS RESTANTES
            let normalizedRemaining = remainingQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let keywords = normalizedRemaining.components(separatedBy: .whitespaces)
                .filter { $0.count >= 2 } // Ignorar conectores de 1 letra
            
            // 3. SCORING AVANZADO
            let scoredPrompts = filtered.map { prompt -> (Prompt, Int) in
                var score = 0
                let title = prompt.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let content = prompt.content.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let folder = (prompt.folder ?? "").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                
                // --- A. VALIDACIÓN DE FRASES COINCIDENTES ("Exact Match") ---
                for phrase in phrasalQueries {
                    if title.contains(phrase) { score += 500 }
                    else if content.contains(phrase) { score += 200 }
                    else { return (prompt, 0) } // Si pidió frase exacta y no está, descartar
                }
                
                // --- B. VALIDACIÓN DE KEYWORDS (Lógica AND Flexible + FUZZY) ---
                for kw in keywords {
                    var kwFound = false
                    
                    // B1. COINCIDENCIA POR PREFIJO (Muy relevante: Escribes "mar" y sale "Marketing")
                    if title.hasPrefix(kw) { score += 150; kwFound = true }
                    else if title.contains(" " + kw) { score += 100; kwFound = true } // Inicio de cualquier palabra en título
                    
                    // B2. FUZZY MATCHING (Tolerancia a 1 error en palabras > 4 letras)
                    if !kwFound && kw.count > 4 {
                        // Comprobamos si hay una coincidencia aproximada (simple fuzzy)
                        // Si la palabra está casi bien escrita en el título
                        let titleWords = title.components(separatedBy: .whitespaces)
                        for word in titleWords where word.count > 3 {
                            if word.commonPrefix(with: kw).count >= kw.count - 1 {
                                score += 60 // Casi coincide
                                kwFound = true
                                break
                            }
                        }
                    }
                    
                    // B3. BÚSQUEDA EN CONTENIDO
                    if !kwFound && content.contains(kw) { 
                        score += 30
                        kwFound = true
                    }
                    
                    // B4. BÚSQUEDA EN CATEGORÍA
                    if !kwFound && folder.contains(kw) {
                        score += 20
                        kwFound = true
                    }
                    
                    // Si el usuario escribió una palabra y no está NI PARECIDA, penalizamos o descartamos
                    if !kwFound { score -= 20 }
                }
                
                // --- C. BONUS POR RECIENCIA Y USO ---
                if score > 0 {
                    score += Int(prompt.useCount) / 2
                    if prompt.isFavorite { score += 40 }
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
        
        // 1. Eliminar Prompts
        let promptRequest: NSFetchRequest<NSFetchRequestResult> = PromptEntity.fetchRequest()
        let deletePrompts = NSBatchDeleteRequest(fetchRequest: promptRequest)
        
        // 2. Eliminar Carpetas
        let folderRequest: NSFetchRequest<NSFetchRequestResult> = FolderEntity.fetchRequest()
        let deleteFolders = NSBatchDeleteRequest(fetchRequest: folderRequest)
        
        do {
            try context.execute(deletePrompts)
            try context.execute(deleteFolders)
            
            // Limpiar flags de seeding para que se vuelvan a crear al recargar
            UserDefaults.standard.removeObject(forKey: "hasSeededDefaultsV21")
            UserDefaults.standard.removeObject(forKey: "hasSeededInitialPromptsV22")
            
            dataController.save()
            
            // Volver a sembrar datos limpios
            seedDefaultFolders()
            seedDefaultPrompts()
            
            loadFolders()
            loadPrompts()
            
            print("⚠️ Base de datos restablecida completamente")
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
