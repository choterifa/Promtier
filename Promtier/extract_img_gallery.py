import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"

with open(path, "r") as f:
    text = f.read()

call_pattern = r"// Prompt Results \(Moved here per user request\)\s*imageGallery\(width: geometry\.size\.width \* 0\.9\)"
replacement = """// Prompt Results
                PromptImageShowcaseView(
                    showcaseImages: $showcaseImages,
                    isDragging: $isDragging,
                    draggedImageIndex: $draggedImageIndex,
                    showingFullScreenImage: $showingFullScreenImage,
                    selectedImageIndex: $selectedImageIndex,
                    branchMessage: $branchMessage,
                    preferences: preferences
                )"""
text = re.sub(call_pattern, replacement, text)

methods_to_remove = [
    r"private func imageGallery\(width: CGFloat\) -> some View \{.*?
                    \}
                \}",
    r"private func handleGalleryDrop\(providers: \[NSItemProvider\], at index: Int\? = nil\) \{.*?
        \}
    \}",
    r"private func isAcceptableImageFile\(_ url: URL\) -> Bool \{.*?
    \}",
    r"private func appendOptimizedImageData\(_ rawData: Data, at index: Int\?\) \{.*?
        \}
    \}",
    r"private var imageTooLargeMessage: String \{.*?
    \}",
    r"private var imageUnsupportedMessage: String \{.*?
    \}",
    r"private var imageSlotsFullMessage: String \{.*?
    \}",
    r"private func showImageImportWarning\(_ message: String\) \{.*?
        \}
    \}",
    r"private func insertImage\(_ data: Data, at index: Int\?\) \{.*?
    \}",
    r"private func importImagesDirectly\(\) \{.*?
        \}
    \}"
]

for p in methods_to_remove:
    text = re.sub(p, "", text, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(text)
