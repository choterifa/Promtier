//
//  SearchViewSimple+PreviewPrewarm.swift
//  Promtier
//
//  Responsabilidad: Gestión del prewarm de assets de preview (texto e imágenes)
//  y el caché en memoria de paths de imágenes de showcase.
//

import SwiftUI

extension SearchViewSimple {

    // MARK: - Preview Path Cache

    func cachedPreviewPaths(for promptId: UUID) -> [String]? {
        previewPathsCache[promptId]
    }

    func storePreviewPathsInCache(_ paths: [String], for promptId: UUID) {
        let maxCacheSize = 40
        if previewPathsCache[promptId] == nil {
            previewCacheOrder.append(promptId)
        }
        previewPathsCache[promptId] = paths

        // Evict oldest entries when over limit
        while previewCacheOrder.count > maxCacheSize {
            let evicted = previewCacheOrder.removeFirst()
            previewPathsCache.removeValue(forKey: evicted)
        }
    }

    // MARK: - Preview Image Paths

    func loadPreviewPaths(for prompt: Prompt) async -> [String] {
        if !prompt.showcaseImagePaths.isEmpty {
            return prompt.showcaseImagePaths
        }
        if let cached = cachedPreviewPaths(for: prompt.id), !cached.isEmpty {
            return cached
        }
        if prompt.showcaseImageCount > 0 {
            return await promptService.fetchShowcaseImagePaths(byId: prompt.id)
        }
        return []
    }

    // MARK: - Primary Prewarm (Text + First 2 images)

    func prewarmPreviewAssets(for prompt: Prompt, force: Bool = false) {
        let key = "\(prompt.id.uuidString):\(Int(preferences.fontSize.scale * 100)):\(prompt.modifiedAt.timeIntervalSince1970)"
        guard force || lastPrewarmedPreviewKey != key else { return }
        lastPrewarmedPreviewKey = key
        prewarmTask?.cancel()

        let scale = preferences.fontSize.scale
        let themeColor = previewThemeColor(for: prompt)
        let interfaceStyle = previewInterfaceStyle

        prewarmTask = Task(priority: .utility) {
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .utility).async {
                    _ = PromptPreviewTextCache.shared.highlightedString(
                        for: prompt, themeColor: themeColor,
                        scale: scale, interfaceStyle: interfaceStyle
                    )
                    continuation.resume()
                }
            }

            guard prompt.showcaseImageCount > 0 else { return }

            var paths = prompt.showcaseImagePaths
            if paths.isEmpty,
               let cached = await MainActor.run(body: { cachedPreviewPaths(for: prompt.id) }),
               !cached.isEmpty { paths = cached }
            if paths.isEmpty {
                paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            }
            if !paths.isEmpty {
                await MainActor.run { storePreviewPathsInCache(paths, for: prompt.id) }
            }

            for (index, relativePath) in paths.prefix(2).enumerated() {
                guard !Task.isCancelled else { return }
                let url = imageStore.url(forRelativePath: relativePath)
                let cacheKey = "\(prompt.id.uuidString):preview:\(index):\(PreviewPrewarmProfile.maxPixelSize):\(relativePath)"
                await ImageDecodeThrottler.prewarm(url: url, cacheKey: cacheKey,
                                                   maxPixelSize: PreviewPrewarmProfile.maxPixelSize)
            }
        }
    }

    // MARK: - Secondary Prewarm (Remaining images)

    func prewarmSecondaryImageAssets(for prompt: Prompt, force: Bool = false) {
        let key = "secondary:\(prompt.id.uuidString):\(prompt.modifiedAt.timeIntervalSince1970)"
        guard force || lastSecondaryImagePrewarmKey != key else { return }
        lastSecondaryImagePrewarmKey = key
        secondaryImagePrewarmTask?.cancel()

        secondaryImagePrewarmTask = Task(priority: .utility) {
            var paths = prompt.showcaseImagePaths

            if paths.isEmpty,
               let cached = await MainActor.run(body: { cachedPreviewPaths(for: prompt.id) }),
               !cached.isEmpty { paths = cached }

            if paths.isEmpty, prompt.showcaseImageCount > 0 {
                paths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            }

            guard !Task.isCancelled, !paths.isEmpty else { return }

            await MainActor.run { storePreviewPathsInCache(paths, for: prompt.id) }

            for (index, relativePath) in paths.prefix(2).enumerated() {
                guard !Task.isCancelled else { return }
                let url = imageStore.url(forRelativePath: relativePath)
                let cacheKey = "\(prompt.id.uuidString):preview:\(index):\(PreviewPrewarmProfile.maxPixelSize):\(relativePath)"
                await ImageDecodeThrottler.prewarm(url: url, cacheKey: cacheKey,
                                                   maxPixelSize: PreviewPrewarmProfile.maxPixelSize)
            }
        }
    }

    // MARK: - Preview Prefetch

    func refreshPreviewPrefetchIfNeeded(for prompt: Prompt) {
        previewPrefetchTask?.cancel()
        previewPrefetchTask = Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }

            let paths = await loadPreviewPaths(for: prompt)
            guard !Task.isCancelled, !paths.isEmpty else { return }

            await MainActor.run {
                prefetchedPreviewPromptId = prompt.id
                prefetchedPreviewPaths = paths
                if !paths.isEmpty { storePreviewPathsInCache(paths, for: prompt.id) }
            }
        }
    }

    // MARK: - Theme Helpers

    func previewThemeColor(for prompt: Prompt) -> PromptPreviewThemeColor {
        if let folder = prompt.folder, let category = PredefinedCategory.fromString(folder) {
            return PromptPreviewThemeColor(NSColor(category.color))
        }
        return PromptPreviewThemeColor(.systemBlue)
    }

    var previewInterfaceStyle: PromptPreviewInterfaceStyle {
        colorScheme == .dark ? .dark : .light
    }
}
