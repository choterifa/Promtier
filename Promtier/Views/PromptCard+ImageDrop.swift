//
//  PromptCard+ImageDrop.swift
//  Promtier
//
//  Responsabilidad: Lógica de arrastre de imágenes sobre una PromptCard.
//  Aislada para que la card principal sea un componente pasivo de presentación.
//

import SwiftUI
import UniformTypeIdentifiers

extension PromptCard {

    // MARK: - Image Drop Handler

    func handleImageDrop(providers: [NSItemProvider]) {
        Task(priority: .userInitiated) {
            let existing = await promptService.fetchShowcaseImages(byId: prompt.id)
            guard existing.count < 3 else { return }

            let available = max(0, 3 - existing.count)
            var optimizedToAdd: [Data] = []

            for provider in providers {
                guard optimizedToAdd.count < available else { break }
                guard let raw = await loadImageData(from: provider) else { continue }

                let optimized = await Task.detached(priority: .userInitiated) {
                    ImageOptimizer.shared.optimize(imageData: raw)
                }.value
                guard let optimized else { continue }
                optimizedToAdd.append(optimized)
            }

            guard !optimizedToAdd.isEmpty else { return }
            let final = Array((existing + optimizedToAdd).prefix(3))
            let ok = await promptService.updateShowcaseImages(promptId: prompt.id, images: final)

            if ok {
                await MainActor.run {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            }
        }
    }

    // MARK: - Image Data Loading

    func loadImageData(from provider: NSItemProvider) async -> Data? {
        if provider.canLoadObject(ofClass: URL.self) {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { continuation.resume(returning: nil); return }
                    continuation.resume(returning: try? Data(contentsOf: url))
                }
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }

        return nil
    }
}
