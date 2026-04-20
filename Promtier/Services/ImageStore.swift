import Foundation
import Combine
import SwiftUI

// MARK: - ImageStore
// Responsabilidad única: gestionar el ciclo de vida de imágenes en disco.
// - Guarda, carga, elimina imágenes de showcase.
// - Caché LRU en memoria para evitar lecturas repetidas del disco.
// - Purga imágenes huérfanas (no referenciadas por ningún prompt activo).

final class ImageStore: ObservableObject, @unchecked Sendable {
    nonisolated static let shared = ImageStore()

    // MARK: - LRU Cache

    nonisolated(unsafe) private let cache = NSCache<NSString, NSData>()
    private let cacheQueue = DispatchQueue(label: "com.promtier.imagestore.cache", attributes: .concurrent)

    private init() {
        // Límite de caché: 64 MB en memoria (thumbnail-level data principalmente)
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    // MARK: - Paths

    nonisolated private var appSupportBaseURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let bundleId = Bundle.main.bundleIdentifier ?? "com.promtier.Promtier"
        return base.appendingPathComponent(bundleId, isDirectory: true)
    }

    nonisolated private var imagesBaseURL: URL {
        appSupportBaseURL.appendingPathComponent("Images", isDirectory: true)
    }

    nonisolated func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: imagesBaseURL, withIntermediateDirectories: true)
    }

    nonisolated func url(forRelativePath relativePath: String) -> URL {
        imagesBaseURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    // MARK: - Save

    /// Guarda una imagen de showcase en disco (optimizada) y devuelve el path relativo + thumbnail.
    nonisolated func saveShowcaseImage(imageData: Data, promptId: UUID, slot: Int) throws -> (relativePath: String, thumbnailData: Data) {
        try ensureDirectories()

        let fm = FileManager.default
        let promptFolder = imagesBaseURL.appendingPathComponent(promptId.uuidString, isDirectory: true)
        try fm.createDirectory(at: promptFolder, withIntermediateDirectories: true)

        guard let optimized = ImageOptimizer.shared.optimizeForDisk(
            imageData: imageData, maxPixelSize: 1200, compressionQuality: 0.82
        ) else {
            throw ImageStoreError.optimizationFailed("No se pudo optimizar la imagen")
        }

        guard let thumb = ImageOptimizer.shared.optimizeForDisk(
            imageData: imageData, maxPixelSize: 480, compressionQuality: 0.7
        ) else {
            throw ImageStoreError.optimizationFailed("No se pudo generar thumbnail")
        }

        let filename = "showcase_\(slot).\(optimized.fileExtension)"
        let fileURL = promptFolder.appendingPathComponent(filename, isDirectory: false)
        try optimized.data.write(to: fileURL, options: [.atomic])

        let relativePath = "\(promptId.uuidString)/\(filename)"

        // Invalidar caché para este path (datos frescos)
        invalidateCache(for: relativePath)

        return (relativePath, thumb.data)
    }

    // MARK: - Load

    nonisolated func loadData(relativePath: String) -> Data? {
        let cacheKey = relativePath as NSString

        // Fast-path: caché en memoria
        if let cached = cache.object(forKey: cacheKey) {
            return cached as Data
        }

        guard let data = try? Data(contentsOf: url(forRelativePath: relativePath)) else { return nil }

        // Almacenar en caché con costo igual al tamaño en bytes
        cache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
        return data
    }

    // MARK: - Existence Check

    nonisolated func fileExists(relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forRelativePath: relativePath).path)
    }

    // MARK: - Deletion

    nonisolated func delete(relativePaths: [String]) {
        let fm = FileManager.default
        for path in relativePaths {
            try? fm.removeItem(at: url(forRelativePath: path))
            invalidateCache(for: path)
        }
    }

    nonisolated func deleteAllImages(for promptId: UUID) {
        let folderURL = imagesBaseURL.appendingPathComponent(promptId.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: folderURL)
        // Invalidar cualquier entrada de caché con este promptId como prefijo
        cache.removeAllObjects()
    }

    nonisolated func wipeAll() {
        try? FileManager.default.removeItem(at: imagesBaseURL)
        cache.removeAllObjects()
    }

    // MARK: - Orphan Purge

    /// Elimina en background carpetas de imágenes que no están en el conjunto de IDs activos.
    /// Llamar después de una operación de borrado masivo para liberar espacio en disco.
    func purgeOrphanedImages(activePromptIds: Set<UUID>) {
        let fm = FileManager.default
        let base = imagesBaseURL

        DispatchQueue.global(qos: .background).async {
            guard let contents = try? fm.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { return }

            var purgedCount = 0
            for itemURL in contents {
                guard let uuidString = itemURL.lastPathComponent.nilIfEmpty,
                      let uuid = UUID(uuidString: uuidString) else { continue }

                if !activePromptIds.contains(uuid) {
                    try? fm.removeItem(at: itemURL)
                    purgedCount += 1
                }
            }

            if purgedCount > 0 {
                print("🖼️ ImageStore: \(purgedCount) carpetas huérfanas eliminadas.")
            }
        }
    }

    // MARK: - Cache Helpers

    nonisolated private func invalidateCache(for relativePath: String) {
        cache.removeObject(forKey: relativePath as NSString)
    }
}

// MARK: - ImageStoreError

enum ImageStoreError: LocalizedError {
    case optimizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .optimizationFailed(let msg): return "ImageStore: \(msg)"
        }
    }
}

// MARK: - String Helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
