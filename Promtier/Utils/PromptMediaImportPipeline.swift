import AppKit
import Foundation
import UniformTypeIdentifiers

enum PromptMediaImportFailure: Error {
    case slotsFull
    case tooLarge
    case unsupported
}

enum PromptMediaImportPipeline {
    static let maxInputBytes = 64 * 1024 * 1024
    static let maxSlots = 3

    static func localizedMessage(for failure: PromptMediaImportFailure, language: AppLanguage) -> String {
        switch failure {
        case .slotsFull:
            return "image_import_slots_full".localized(for: language)
        case .tooLarge:
            let format = "image_import_too_large".localized(for: language)
            return String(format: format, maxInputBytes / (1024 * 1024))
        case .unsupported:
            return "image_import_unsupported".localized(for: language)
        }
    }

    static func optimizeImageData(_ rawData: Data) -> Result<Data, PromptMediaImportFailure> {
        guard rawData.count <= maxInputBytes else {
            return .failure(.tooLarge)
        }

        guard let optimized = ImageOptimizer.shared.optimize(imageData: rawData) else {
            return .failure(.unsupported)
        }

        return .success(optimized)
    }

    static func loadRawData(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                guard let nsImage = image as? NSImage,
                      let tiffData = nsImage.tiffRepresentation else {
                    completion(nil)
                    return
                }
                completion(tiffData)
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                completion(data)
            }
            return
        }

        completion(nil)
    }
}
