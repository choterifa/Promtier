import Foundation

final class ImageStore: @unchecked Sendable {
    nonisolated static let shared = ImageStore()

    private init() {}

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
        let fm = FileManager.default
        try fm.createDirectory(at: imagesBaseURL, withIntermediateDirectories: true)
    }

    nonisolated func url(forRelativePath relativePath: String) -> URL {
        imagesBaseURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    /// Guarda una imagen de showcase en disco (optimizada) y devuelve el path relativo + thumbnail.
    nonisolated func saveShowcaseImage(imageData: Data, promptId: UUID, slot: Int) throws -> (relativePath: String, thumbnailData: Data) {
        try ensureDirectories()

        let fm = FileManager.default
        let promptFolder = imagesBaseURL.appendingPathComponent(promptId.uuidString, isDirectory: true)
        try fm.createDirectory(at: promptFolder, withIntermediateDirectories: true)

        guard let optimized = ImageOptimizer.shared.optimizeForDisk(imageData: imageData, maxPixelSize: 1200, compressionQuality: 0.82) else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo optimizar la imagen"])
        }

        guard let thumb = ImageOptimizer.shared.optimizeForDisk(imageData: imageData, maxPixelSize: 480, compressionQuality: 0.7) else {
            throw NSError(domain: "ImageStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo generar thumbnail"])
        }

        let filename = "showcase_\(slot).\(optimized.fileExtension)"
        let fileURL = promptFolder.appendingPathComponent(filename, isDirectory: false)
        try optimized.data.write(to: fileURL, options: [.atomic])

        let relativePath = "\(promptId.uuidString)/\(filename)"
        return (relativePath, thumb.data)
    }

    nonisolated func loadData(relativePath: String) -> Data? {
        try? Data(contentsOf: url(forRelativePath: relativePath))
    }

    nonisolated func fileExists(relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forRelativePath: relativePath).path)
    }

    nonisolated func delete(relativePaths: [String]) {
        let fm = FileManager.default
        for path in relativePaths {
            let fileURL = url(forRelativePath: path)
            try? fm.removeItem(at: fileURL)
        }
    }

    nonisolated func deleteAllImages(for promptId: UUID) {
        let fm = FileManager.default
        let folderURL = imagesBaseURL.appendingPathComponent(promptId.uuidString, isDirectory: true)
        try? fm.removeItem(at: folderURL)
    }

    nonisolated func wipeAll() {
        let fm = FileManager.default
        try? fm.removeItem(at: imagesBaseURL)
    }
}
