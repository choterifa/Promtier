import Foundation

// MARK: - ShowcaseImageLoader
// Responsabilidad única: resolver imágenes de showcase desde cualquier fuente disponible.
//
// Centraliza la cadena de fallback (paths en disco → blobs legacy → thumbnails)
// en un solo punto, eliminando la duplicación entre ViewModel, View y Repository.

enum ShowcaseImageLoader {

    /// Resultado de una operación de carga con metadata de la fuente utilizada.
    struct LoadResult {
        let images: [Data]
        let source: Source

        var isEmpty: Bool { images.isEmpty }

        enum Source {
            case diskPaths       // Imágenes completas desde disco (flujo moderno)
            case legacyBlobs     // Blobs de CoreData (pre-migración)
            case thumbnails      // Thumbnails de baja resolución (último recurso)
            case none            // No se encontraron imágenes
        }
    }

    /// Carga imágenes de showcase para un prompt, recorriendo la cadena de fallback completa.
    ///
    /// Orden de resolución:
    /// 1. Paths en disco (ImageStore) — fuente principal, post-migración
    /// 2. Blobs legacy en CoreData — prompts que aún no han sido migrados
    /// 3. Thumbnails — si el archivo original fue eliminado o está desincronizado (iCloud)
    ///
    /// - Parameters:
    ///   - promptId: ID del prompt a cargar.
    ///   - promptService: Servicio de prompts para acceder al repositorio.
    ///   - knownThumbnails: Thumbnails ya conocidos del modelo `Prompt` (evita fetch adicional).
    ///   - expectedCount: Cantidad esperada de imágenes según `showcaseImageCount`.
    /// - Returns: `LoadResult` con las imágenes encontradas y la fuente utilizada.
    static func loadImages(
        for promptId: UUID,
        using promptService: PromptService,
        knownThumbnails: [Data] = [],
        expectedCount: Int = 0
    ) async -> LoadResult {
        guard expectedCount > 0 else {
            return LoadResult(images: [], source: .none)
        }

        // 1. Intentar cargar desde paths en disco (flujo moderno)
        let paths = await promptService.fetchShowcaseImagePaths(byId: promptId)
        if !paths.isEmpty {
            let diskImages = promptService.loadShowcaseImages(from: paths)
            if !diskImages.isEmpty {
                return LoadResult(images: diskImages, source: .diskPaths)
            }
        }

        // 2. Fallback: blobs legacy en CoreData
        let legacyImages = await promptService.fetchShowcaseImages(byId: promptId)
        if !legacyImages.isEmpty {
            return LoadResult(images: legacyImages, source: .legacyBlobs)
        }

        // 3. Último recurso: thumbnails del modelo
        if !knownThumbnails.isEmpty {
            return LoadResult(images: knownThumbnails, source: .thumbnails)
        }

        return LoadResult(images: [], source: .none)
    }
}
