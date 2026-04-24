import Foundation
import CoreData
import SwiftUI

final class PromptExportService {
    let dataController: DataController
    weak var promptService: PromptService?

    init(dataController: DataController, promptService: PromptService) {
        self.dataController = dataController
        self.promptService = promptService
    }

    private var prompts: [Prompt] {
        return promptService?.prompts ?? []
    }
    
    private var folders: [Folder] {
        return promptService?.folders ?? []
    }
    
    private func loadFolders() {
        DispatchQueue.main.async { self.promptService?.loadFolders() }
    }
    
    private func loadPrompts() {
        DispatchQueue.main.async { self.promptService?.loadPrompts() }
    }
    
    private func createFolder(_ folder: Folder) -> Bool {
        return promptService?.createFolder(folder) ?? false
    }
    
    private func createPrompt(_ prompt: Prompt) -> Bool {
        return promptService?.createPrompt(prompt) ?? false
    }

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
            // Export debe incluir imágenes aunque la lista use lazy-load.
            // NOTA: JSON es portable (incluye imágenes en base64), pero puede ser pesado.
            let context: NSManagedObjectContext = dataController.backgroundContext
            var allPrompts: [Prompt] = []
            var allFolders: [Folder] = []

            context.performAndWaitCompat {
                do {
                    let folderRequest = FolderEntity.fetchAll(in: context)
                    allFolders = try context.fetch(folderRequest).map { $0.toFolder() }

                    let request = PromptEntity.fetchAll(in: context)
                    let entities = try context.fetch(request)
                    allPrompts = entities.map { entity in
                        var p = entity.toPrompt()
                        // Incluir imágenes completas (para que el JSON sea auto-contenido).
                        if !p.showcaseImagePaths.isEmpty {
                            p.showcaseImages = self.promptService?.loadShowcaseImages(
                                from: p.showcaseImagePaths,
                                maxImages: PromptService.ShowcaseImageLoadPolicy.runtimeMaxImages
                            ) ?? []
                            p.showcaseImageCount = p.showcaseImages.count
                        } else {
                            let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                            p.showcaseImages = legacy
                            p.showcaseImageCount = legacy.count
                        }
                        return p
                    }
                } catch {
                    print("❌ Error preparando export JSON: \(error)")
                }
            }

            let prefs = PreferencesManager.shared
            let package = BackupPackage(
                version: "3.1", // Incrementamos versión por nuevos campos
                prompts: allPrompts,
                folders: allFolders,
                appSettings: [
                    "appearance": prefs.appearance.rawValue,
                    "fontSize": prefs.fontSize.rawValue,
                    "closeOnCopy": String(prefs.closeOnCopy),
                    "autoPaste": String(prefs.autoPaste),
                    "soundEnabled": String(prefs.soundEnabled),
                    "language": prefs.language.rawValue,
                    "isGridView": String(prefs.isGridView),
                    "showSidebar": String(prefs.showSidebar),
                    "hotkeyCode": String(prefs.hotkeyCode),
                    "hotkeyModifiers": String(prefs.hotkeyModifiers)
                ],
                snippets: prefs.snippets,
                aiDraftPresets: prefs.draftPresets
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

    /// Exporta un backup completo en ZIP (manifest JSON + carpeta Images con archivos).
    /// - Importante: a diferencia del JSON, el manifest NO incluye imágenes en base64.
    func exportBackupZip(to destinationZipURL: URL) -> Bool {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("promtier_backup_\(UUID().uuidString)", isDirectory: true)
        let bundleRoot = tempRoot.appendingPathComponent("Promtier Backup", isDirectory: true)
        let imagesRoot = bundleRoot.appendingPathComponent("Images", isDirectory: true)
        let manifestURL = bundleRoot.appendingPathComponent("manifest.json", isDirectory: false)

        do {
            try fm.createDirectory(at: imagesRoot, withIntermediateDirectories: true)

            let context: NSManagedObjectContext = dataController.backgroundContext
            var allPrompts: [Prompt] = []
            var allFolders: [Folder] = []

            context.performAndWaitCompat {
                do {
                    let folderRequest = FolderEntity.fetchAll(in: context)
                    allFolders = try context.fetch(folderRequest).map { $0.toFolder() }

                    let request: NSFetchRequest<PromptEntity> = PromptEntity.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "useCount", ascending: false),
                        NSSortDescriptor(key: "modifiedAt", ascending: false)
                    ]
                    let entities = try context.fetch(request)

                    // Asegurar que prompts legacy tengan paths en disco antes de exportar.
                    var didChange = false
                    for entity in entities {
                        let hasPaths = (entity.image1Path != nil || entity.image2Path != nil || entity.image3Path != nil)
                        if !hasPaths {
                            let legacy = [entity.image1, entity.image2, entity.image3].compactMap { $0 }
                            if !legacy.isEmpty {
                                self.promptService?.applyShowcaseImages(legacy, to: entity, promptId: entity.id, clearExisting: true)
                                didChange = true
                            }
                        }
                    }
                    if didChange, context.hasChanges {
                        try context.save()
                    }

                    allPrompts = entities.map { entity in
                        var p = entity.toPrompt()
                        // Mantener manifest ligero: las imágenes viajan como archivos en /Images (y thumbs se regeneran al importar).
                        p.showcaseThumbnails = []
                        p.showcaseImages = []
                        return p
                    }
                } catch {
                    print("❌ Error preparando backup ZIP: \(error)")
                }
            }

            let archive = BackupArchive(
                version: "3.0",
                exportedAt: Date(),
                prompts: allPrompts,
                folders: allFolders
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let manifestData = try encoder.encode(archive)
            try manifestData.write(to: manifestURL, options: [.atomic])

            // Copiar imágenes referenciadas al bundle (sin cargar en memoria completa).
            var copied = Set<String>()
            for prompt in allPrompts {
                for rel in Array(prompt.showcaseImagePaths.prefix(3)) {
                    guard let safeRel = sanitizeRelativeImagePath(rel) else { continue }
                    guard copied.insert(safeRel).inserted else { continue }

                    let sourceURL = ImageStore.shared.url(forRelativePath: safeRel)
                    guard fm.fileExists(atPath: sourceURL.path) else { continue }

                    let destURL = imagesRoot.appendingPathComponent(safeRel, isDirectory: false)
                    try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if fm.fileExists(atPath: destURL.path) { try? fm.removeItem(at: destURL) }
                    try fm.copyItem(at: sourceURL, to: destURL)
                }
            }

            if fm.fileExists(atPath: destinationZipURL.path) { try? fm.removeItem(at: destinationZipURL) }
            try ZipService.zip(directory: bundleRoot, to: destinationZipURL)
            try? fm.removeItem(at: tempRoot)
            return true
        } catch {
            print("❌ Error exportando backup ZIP: \(error)")
            try? fm.removeItem(at: tempRoot)
            return false
        }
    }

    /// Importa un backup ZIP (manifest + Images). No sobrescribe prompts existentes por ID.
    func importBackupZip(from zipURL: URL) -> (success: Int, failed: Int, foldersCreated: Int) {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("promtier_import_\(UUID().uuidString)", isDirectory: true)

        do {
            try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            try ZipService.unzip(zipFile: zipURL, to: tempRoot)

            guard let manifestURL = findFirstFile(named: "manifest.json", under: tempRoot) else {
                print("❌ ZIP inválido: no se encontró manifest.json")
                try? fm.removeItem(at: tempRoot)
                return (0, 0, 0)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(BackupArchive.self, from: Data(contentsOf: manifestURL))

            // El bundle root es el directorio donde vive el manifest.
            let bundleRoot = manifestURL.deletingLastPathComponent()
            let imagesRoot = bundleRoot.appendingPathComponent("Images", isDirectory: true)

            let context: NSManagedObjectContext = dataController.backgroundContext
            let (successCount, failedCount, foldersCreated) = context.performAndWaitCompat { [self] in
                var sCount = 0
                var fCount = 0
                var cCount = 0
                do {
                    // Cache de existentes por ID para evitar fetch por item.
                    let existingPromptIds = try self.fetchExistingPromptIds(in: context)
                    let existingFolderIds = try self.fetchExistingFolderIds(in: context)
                    let existingFolderNames = try self.fetchExistingFolderNames(in: context)

                    var promptIdSet = existingPromptIds
                    var folderIdSet = existingFolderIds
                    var folderNameSet = existingFolderNames

                    // 1) Carpetas
                    for folder in archive.folders {
                        if folderIdSet.contains(folder.id) || folderNameSet.contains(folder.name) { continue }
                        _ = FolderEntity.create(from: folder, in: context)
                        cCount += 1
                        folderIdSet.insert(folder.id)
                        folderNameSet.insert(folder.name)
                    }

                    // 2) Prompts
                    for prompt in archive.prompts {
                        if promptIdSet.contains(prompt.id) {
                            fCount += 1
                            continue
                        }

                        let entity = PromptEntity(context: context)
                        entity.id = prompt.id
                        entity.createdAt = prompt.createdAt
                        entity.updateFromPrompt(prompt)

                        let paths = Array(prompt.showcaseImagePaths.prefix(3)).compactMap(self.sanitizeRelativeImagePath(_:))
                        var thumbs: [Data] = []

                        if !paths.isEmpty {
                            for rel in paths {
                                let sourceURL = imagesRoot.appendingPathComponent(rel, isDirectory: false)
                                guard fm.fileExists(atPath: sourceURL.path) else { continue }

                                let destURL = ImageStore.shared.url(forRelativePath: rel)
                                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                                if fm.fileExists(atPath: destURL.path) { try? fm.removeItem(at: destURL) }
                                try fm.copyItem(at: sourceURL, to: destURL)

                                if let data = try? Data(contentsOf: destURL),
                                   let thumb = ImageOptimizer.shared.optimizeForDisk(imageData: data, maxPixelSize: 480, compressionQuality: 0.7)?.data {
                                    thumbs.append(thumb)
                                }
                            }
                        }

                        entity.image1Path = paths.indices.contains(0) ? paths[0] : nil
                        entity.image2Path = paths.indices.contains(1) ? paths[1] : nil
                        entity.image3Path = paths.indices.contains(2) ? paths[2] : nil

                        entity.thumb1 = thumbs.indices.contains(0) ? thumbs[0] : nil
                        entity.thumb2 = thumbs.indices.contains(1) ? thumbs[1] : nil
                        entity.thumb3 = thumbs.indices.contains(2) ? thumbs[2] : nil

                        entity.image1 = nil
                        entity.image2 = nil
                        entity.image3 = nil

                        entity.showcaseImageCount = Int16(paths.count)

                        sCount += 1
                        promptIdSet.insert(prompt.id)

                        if sCount % 50 == 0, context.hasChanges {
                            try context.save()
                        }
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    print("❌ Error importando backup ZIP: \(error)")
                }
                
                return (sCount, fCount, cCount)
            }

            DispatchQueue.main.async {
                self.loadFolders()
                self.loadPrompts()
            }

            try? fm.removeItem(at: tempRoot)
            return (successCount, failedCount, foldersCreated)
        } catch {
            print("❌ Error leyendo ZIP: \(error)")
            try? fm.removeItem(at: tempRoot)
            return (0, 0, 0)
        }
    }

    private func sanitizeRelativeImagePath(_ path: String) -> String? {
        if path.isEmpty { return nil }
        if path.hasPrefix("/") { return nil }
        let components = (path as NSString).pathComponents
        if components.contains("..") { return nil }
        return path
    }

    private func findFirstFile(named filename: String, under directory: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent == filename { return url }
        }
        return nil
    }

    private func fetchExistingPromptIds(in context: NSManagedObjectContext) throws -> Set<UUID> {
        let request = NSFetchRequest<NSDictionary>(entityName: "PromptEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["id"] as? UUID })
    }

    private func fetchExistingFolderIds(in context: NSManagedObjectContext) throws -> Set<UUID> {
        let request = NSFetchRequest<NSDictionary>(entityName: "FolderEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["id"] as? UUID })
    }

    private func fetchExistingFolderNames(in context: NSManagedObjectContext) throws -> Set<String> {
        let request = NSFetchRequest<NSDictionary>(entityName: "FolderEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["name"]
        let rows = try context.fetch(request)
        return Set(rows.compactMap { $0["name"] as? String })
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
        rows.append("id,title,content,folder,icon,isFavorite,useCount,createdAt,modifiedAt,lastUsedAt,negativePrompt,alternatives")
        
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
                csv(iso.string(from: p.modifiedAt)),
                csv(p.lastUsedAt != nil ? iso.string(from: p.lastUsedAt!) : ""),
                csv(p.negativePrompt ?? ""),
                csv(p.alternatives.joined(separator: " | "))
            ].joined(separator: ",")
            rows.append(row)
        }
        
        let csvString = rows.joined(separator: "\n")
        return csvString.data(using: .utf8)
    }
    
    /// Importa datos desde un archivo JSON (Soporta formato antiguo y nuevo BackupPackage)
    func importPromptsFromData(_ data: Data, overwrite: Bool = false) -> (success: Int, failed: Int, foldersCreated: Int) {
        if overwrite {
            print("⚠️ Ejecutando restauración total (overwrite mode)")
            dataController.deleteAll()
            // Limpiar todas las imágenes para evitar huérfanos en disco e iCloud
            ImageStore.shared.wipeAll()
            // Recargar para limpiar el estado en memoria
            loadFolders()
            loadPrompts()
        }
        
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
        
        // 3. Importar Snippets y Presets (Novedad v3.1)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let package = try decoder.decode(BackupPackage.self, from: data)
            
            let prefs = PreferencesManager.shared
            
            // Importar Snippets (solo si no existen por título)
            if let importedSnippets = package.snippets {
                for snippet in importedSnippets {
                    if !prefs.snippets.contains(where: { $0.title == snippet.title }) {
                        prefs.snippets.append(snippet)
                    }
                }
            }
            
            // Importar Presets de AI Draft
            if let importedPresets = package.aiDraftPresets {
                for preset in importedPresets {
                    if !prefs.draftPresets.contains(where: { $0.title == preset.title }) {
                        prefs.draftPresets.append(preset)
                    }
                }
            }
            
            // Importar Settings (Opcional, podrías preguntar al usuario, pero por ahora lo aplicamos)
            if let settings = package.appSettings {
                if let app = settings["appearance"] { prefs.appearance = AppAppearance(rawValue: app) ?? .system }
                if let lang = settings["language"] { prefs.language = AppLanguage(rawValue: lang) ?? .english }
                // etc...
            }
            
        } catch {
            // Si falla esta parte no es crítica, los prompts ya se importaron
            print("ℹ️ Backup no contenía metadatos extendidos o formato antiguo.")
        }
        
        loadFolders()
        loadPrompts()
        return (successCount, failedCount, foldersCreated)
    }
}

struct BackupPackage: Codable {
    var version: String
    var prompts: [Prompt]
    var folders: [Folder]
    
    // Nuevos campos para respaldo integral (Opcionales para compatibilidad)
    var appSettings: [String: String]? // Preferencias serializadas
    var snippets: [Snippet]?
    var aiDraftPresets: [DraftPreset]?
}
