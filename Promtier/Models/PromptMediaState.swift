import Foundation

struct PromptMediaState: Equatable {
    var draggedImageIndex: Int? = nil
    var selectedImageIndex: Int = 0
    var fullScreenImageData: Data? = nil

    mutating func clampSelection(for images: [Data]) {
        if images.isEmpty {
            selectedImageIndex = 0
            fullScreenImageData = nil
            return
        }
        selectedImageIndex = max(0, min(selectedImageIndex, images.count - 1))
    }
}
