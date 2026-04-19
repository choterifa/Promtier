//
//  PromptImageShowcaseView.swift
//  Promtier
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PromptImageShowcaseView: View {
    @Binding var showcaseImages: [Data]
    @Binding var draggedImageIndex: Int?
    @Binding var showingFullScreenImage: Data?
    @Binding var selectedImageIndex: Int
    @Binding var branchMessage: String?
    
    let preferences: PreferencesManager
    let themeColor: Color
    
    private enum ImageImportPolicy {
        static let maxInputBytes = 64 * 1024 * 1024
        static let maxSlots = 3
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeColor)
                Text("prompt_results".localized(for: preferences.language).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                if showcaseImages.count < ImageImportPolicy.maxSlots {
                    Button(action: importImagesDirectly) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeColor)
                    }
                    .buttonStyle(.plain)
                    .help("add_image".localized(for: preferences.language))
                }
                Spacer()
            }
            .padding(.horizontal, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<ImageImportPolicy.maxSlots, id: \.self) { index in
                        if index < showcaseImages.count {
                            imageSlot(index: index)
                        } else {
                            PlaceholderSlotView(
                                slotWidth: 100, // Ajustado dinámicamente o por pref
                                slotHeight: 66,
                                onSelect: importImagesDirectly,
                                onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                                tintColor: themeColor
                            )
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .frame(height: 90) 
        }
        .padding(.top, 16)
        .onPasteCommand(of: [.image]) { providers in
            handleGalleryDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private func imageSlot(index: Int) -> some View {
        let slotWidth: CGFloat = 100
        let slotHeight: CGFloat = 66
        
        ImageSlotView(
            imageData: showcaseImages[index],
            slotWidth: slotWidth,
            slotHeight: slotHeight,
            isSelected: selectedImageIndex == index,
            tintColor: themeColor,
            onRemove: { 
                showcaseImages.remove(at: index)
                if selectedImageIndex >= showcaseImages.count {
                    selectedImageIndex = max(0, showcaseImages.count - 1)
                }
            },
            onPreview: { 
                selectedImageIndex = index
                showingFullScreenImage = showcaseImages[index] 
            },
            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
            onDragStart: { self.draggedImageIndex = index }
        )
    }

    private func handleGalleryDrop(providers: [NSItemProvider], at index: Int? = nil) {
        if let sourceIndex = draggedImageIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let item = showcaseImages.remove(at: sourceIndex)
                let targetIndex = min(index ?? showcaseImages.count, showcaseImages.count)
                showcaseImages.insert(item, at: targetIndex)
                HapticService.shared.playLight()
            }
            draggedImageIndex = nil
            return
        }

        let remainingSlots = max(0, ImageImportPolicy.maxSlots - showcaseImages.count)
        guard remainingSlots > 0 else {
            showImageImportWarning("image_import_slots_full".localized(for: preferences.language))
            return
        }

        for provider in providers.prefix(remainingSlots) {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        DispatchQueue.global(qos: .userInitiated).async {
                            guard let tiffData = nsImage.tiffRepresentation else { return }
                            self.appendOptimizedImageData(tiffData, at: index)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data {
                        self.appendOptimizedImageData(data, at: index)
                    }
                }
            }
        }
    }

    private func importImagesDirectly() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        guard panel.runModal() == .OK else { return }
        
        let remainingSlots = max(0, ImageImportPolicy.maxSlots - self.showcaseImages.count)
        guard remainingSlots > 0 else {
            self.showImageImportWarning("image_import_slots_full".localized(for: preferences.language))
            return
        }

        let urls = Array(panel.urls.prefix(remainingSlots))
        for url in urls {
            if let data = try? Data(contentsOf: url) {
                self.appendOptimizedImageData(data, at: nil)
            }
        }
    }
    
    private func appendOptimizedImageData(_ rawData: Data, at index: Int?) {
        if let optimized = ImageOptimizer.shared.optimize(imageData: rawData) {
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    if let target = index, target < showcaseImages.count {
                        showcaseImages.insert(optimized, at: target)
                    } else if showcaseImages.count < ImageImportPolicy.maxSlots {
                        showcaseImages.append(optimized)
                    }
                }
                HapticService.shared.playSuccess()
            }
        }
    }
    
    private func showImageImportWarning(_ message: String) {
        HapticService.shared.playError()
        withAnimation {
            branchMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if branchMessage == message { branchMessage = nil }
            }
        }
    }
}
