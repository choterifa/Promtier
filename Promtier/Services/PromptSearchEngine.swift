import Foundation
import SwiftUI

struct PromptSearchDocument: Sendable {
    let normalizedTitle: String
    let normalizedContent: String
    let normalizedFolder: String
    let titleWords: [String]
}

final class PromptSearchEngine {
    private var searchIndex: [UUID: PromptSearchDocument] = [:]
    private var filterTask: Task<Void, Never>?

    func normalizeForSearch(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    func buildSearchDocument(for prompt: Prompt) -> PromptSearchDocument {
        let normalizedTitle = normalizeForSearch(prompt.title)
        let normalizedContent = normalizeForSearch(String(prompt.content.prefix(1600)))
        let normalizedFolder = normalizeForSearch(prompt.folder ?? "")
        let titleWords = normalizedTitle.split(whereSeparator: \.isWhitespace).map(String.init)

        return PromptSearchDocument(
            normalizedTitle: normalizedTitle,
            normalizedContent: normalizedContent,
            normalizedFolder: normalizedFolder,
            titleWords: titleWords
        )
    }

    func rebuildPromptIndices(with prompts: [Prompt]) {
        var documents: [UUID: PromptSearchDocument] = [:]
        documents.reserveCapacity(prompts.count)

        for prompt in prompts {
            documents[prompt.id] = buildSearchDocument(for: prompt)
        }

        searchIndex = documents
    }

    func upsertPromptIndices(with prompt: Prompt) {
        searchIndex[prompt.id] = buildSearchDocument(for: prompt)
    }

    func removePromptIndices(for id: UUID) {
        searchIndex.removeValue(forKey: id)
    }


    func filterPrompts(prompts: [Prompt], folders: [Folder], query: String, categoryOverride: String? = "USE_CURRENT", selectedCategory: String?, activeAppBundleID: String?, promptSortMode: PromptService.PromptSortMode, completion: @escaping ([Prompt]) -> Void) {
        filterTask?.cancel()

        let determinedCategory: String?
        if let override = categoryOverride, override == "USE_CURRENT" {
            determinedCategory = selectedCategory
        } else {
            determinedCategory = categoryOverride
        }

        var allowedCategories: Set<String>? = nil
        if let targetCat = determinedCategory, !["all", "recent", "favorites", "uncategorized"].contains(targetCat) {
            var validNames: Set<String> = [targetCat]
            let includeSubcategoryPrompts = PreferencesManager.shared.includeSubcategoryPrompts
            
            if includeSubcategoryPrompts, let rootFolder = folders.first(where: { $0.name == targetCat }) {
                var toProcess = [rootFolder.id]
                var processed = Set<UUID>()

                while !toProcess.isEmpty {
                    let currentId = toProcess.removeFirst()
                    processed.insert(currentId)

                    let children = folders.filter { $0.parentId == currentId }
                    for child in children {
                        validNames.insert(child.name)
                        if !processed.contains(child.id) {
                            toProcess.append(child.id)
                        }
                    }
                }
            }
            allowedCategories = validNames
        }        
        let safePrompts = prompts
        let safeActiveApp = activeAppBundleID
        let safeSortMode = promptSortMode
        let safeSearchIndex = self.searchIndex
        let indexedContentCharacterLimit = 1600
        let minKeywordLength = 2
        let quotedPhrasesRegex = try? NSRegularExpression(pattern: "\"([^\"]+)\"", options: [])
        let normalizeSearch: (String) -> String = { text in
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        let buildDocument: (Prompt) -> PromptSearchDocument = { prompt in
            let normalizedTitle = normalizeSearch(prompt.title)
            let normalizedContent = normalizeSearch(String(prompt.content.prefix(indexedContentCharacterLimit)))
            let normalizedFolder = normalizeSearch(prompt.folder ?? "")
            let titleWords = normalizedTitle.split(whereSeparator: \.isWhitespace).map(String.init)
            return PromptSearchDocument(
                normalizedTitle: normalizedTitle,
                normalizedContent: normalizedContent,
                normalizedFolder: normalizedFolder,
                titleWords: titleWords
            )
        }
        
        filterTask = Task.detached(priority: .userInitiated) {
            if Task.isCancelled { return }
            var filtered = safePrompts
            
            if Task.isCancelled { return }
            
            // Filtrar por categoría si hay una seleccionada
            if let allowed = allowedCategories {
                filtered = safePrompts.filter {
                    if let folder = $0.folder { return allowed.contains(folder) }
                    return false
                }
            } else if let category = determinedCategory {
                switch category {
                case "recent":
                    let fortyEightHoursAgo = Date().addingTimeInterval(-48 * 3600)
                    let recentlyUsed = safePrompts.filter {
                        if let lastUsed = $0.lastUsedAt { return lastUsed > fortyEightHoursAgo }
                        return false
                    }
                    
                    let mostUsed = safePrompts.filter { $0.useCount > 0 }
                        .sorted { $0.useCount > $1.useCount }
                        .prefix(10)
                    
                    var combined = recentlyUsed
                    for p in mostUsed {
                        if !combined.contains(where: { $0.id == p.id }) {
                            combined.append(p)
                        }
                    }
                    
                    combined.sort { ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast) }
                    filtered = Array(combined.prefix(7))
                    
                case "favorites":
                    filtered = filtered.filter { $0.isFavorite }
                    filtered.sort { $0.useCount > $1.useCount }
                    
                case "uncategorized":
                    filtered = filtered.filter { $0.folder == nil || $0.folder == "" }
                case "all":
                    break
                default:
                    filtered = filtered.filter { $0.folder == category }
                }
            }
            
            if Task.isCancelled { return }
            
            // --- Smart Boost based on Active Application ---
            if let activeApp = safeActiveApp, !activeApp.isEmpty, query.isEmpty {
                let matched = filtered.filter { $0.targetAppBundleIDs.contains(activeApp) }
                let others = filtered.filter { !$0.targetAppBundleIDs.contains(activeApp) }
                filtered = matched + others
            }
            
            // Filtrar por texto si hay consulta - MOTOR DE BÚSQUEDA AVANZADO
            if !query.isEmpty {
                // 0. SANITIZACIÓN Y NORMALIZACIÓN
                let sanitized = query.replacingOccurrences(of: "[\\x00-\\x1F\\x7F]", with: "", options: .regularExpression)
                let normalizedSpaces = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let originalQuery = normalizedSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !originalQuery.isEmpty else {
                    if !Task.isCancelled {
                        let resultToSet = filtered
                        await MainActor.run { completion(resultToSet) }
                    }
                    return
                }
                
                // 1. EXTRAER FRASES EXACTAS (entre comillas)
                var phrasalQueries: [String] = []
                var remainingQuery = originalQuery
                
                if let matches = quotedPhrasesRegex?.matches(in: originalQuery, options: [], range: NSRange(originalQuery.startIndex..., in: originalQuery)) {
                    for match in matches.reversed() { // Reversa para no corromper índices al remover
                        if let range = Range(match.range(at: 1), in: originalQuery) {
                            phrasalQueries.append(normalizeSearch(String(originalQuery[range])))
                        }
                        if let fullRange = Range(match.range(at: 0), in: originalQuery) {
                            remainingQuery.removeSubrange(fullRange)
                        }
                    }
                }
                
                // 2. NORMALIZACIÓN Y KEYWORDS RESTANTES
                let normalizedRemaining = normalizeSearch(remainingQuery)
                let keywords = normalizedRemaining
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                    .filter { $0.count >= minKeywordLength } // Ignorar conectores de 1 letra
                
                // 3. SCORING AVANZADO
                let scoredPrompts = filtered.map { prompt -> (Prompt, Int) in
                    var score = 0
                    let document = safeSearchIndex[prompt.id] ?? buildDocument(prompt)
                    let title = document.normalizedTitle
                    let content = document.normalizedContent
                    let folder = document.normalizedFolder
                    
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
                            for word in document.titleWords where word.count > 3 {
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
                        
                        // Bonus por reciencia: Si se tocó en la última semana, impulsamos un poco
                        let lastWeek = Date().addingTimeInterval(-7 * 86400)
                        if prompt.modifiedAt > lastWeek {
                            score += 30
                        }
                        if prompt.modifiedAt > Date().addingTimeInterval(-24 * 3600) {
                            score += 20 // Acumulativo si es muy muy reciente
                        }
                        
                        // BONUS POR APP ACTIVA
                        if let activeApp = safeActiveApp, prompt.targetAppBundleIDs.contains(activeApp) {
                            score += 500 // Impulso masivo para matches de app
                        }
                    }
                    
                    return (prompt, score)
                }
                
                if Task.isCancelled { return }
                
                filtered = scoredPrompts
                    .filter { $0.1 > 0 }
                    .sorted { $0.1 > $1.1 }
                    .map { $0.0 }
            }
            
            if Task.isCancelled { return }
            
            // --- Terminal Global Sort ---
            if query.isEmpty {
                switch safeSortMode {
                case .name:
                    filtered.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
                case .newest:
                    // Priorizar los más recientemente modificados para que reflejen la actividad real
                    filtered.sort { $0.modifiedAt > $1.modifiedAt }
                case .mostUsed:
                    filtered.sort { $0.useCount > $1.useCount }
                }
            }
            
            // --- RECOMMENDED ALWAYS ON TOP ---
            // Un prompt es "Recomendado" solo si su array de aplicaciones asignadas
            // INCLUYE la aplicación activa actual en pantalla.
            let recommended: [Prompt]
            let others: [Prompt]
            if let activeApp = safeActiveApp {
                recommended = filtered.filter { $0.targetAppBundleIDs.contains(activeApp) }
                others = filtered.filter { !$0.targetAppBundleIDs.contains(activeApp) }
            } else {
                recommended = []
                others = filtered
            }
            let finalFiltered = recommended + others
            
            if !Task.isCancelled {
                await MainActor.run {
                    completion(finalFiltered)
                }
            }
        }
    }

}
