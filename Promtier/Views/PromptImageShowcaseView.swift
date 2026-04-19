//
//  PromptImageShowcaseView.swift
//  Promtier
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PromptImageShowcaseView: View {
    @Binding var showcaseImages: [Data]
    @Binding var mediaState: PromptMediaState
    @Binding var branchMessage: String?
    
    let preferences: PreferencesManager
    let themeColor: Color
    
    private enum ShowcaseLayout {
        static let slotWidth: CGFloat = 112
        static let slotHeight: CGFloat = 76
        static let rowHeight: CGFloat = 104
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
                
                if showcaseImages.count < PromptMediaImportPipeline.maxSlots {
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
                    ForEach(0..<PromptMediaImportPipeline.maxSlots, id: \.self) { index in
                        if index < showcaseImages.count {
                            imageSlot(index: index)
                        } else {
                            PlaceholderSlotView(
                                slotWidth: ShowcaseLayout.slotWidth,
                                slotHeight: ShowcaseLayout.slotHeight,
                                onSelect: importImagesDirectly,
                                onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
                                displayTextKey: "add_image",
                                tintColor: themeColor
                            )
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .frame(height: ShowcaseLayout.rowHeight)
        }
        .padding(.top, 16)
        .onPasteCommand(of: [.image]) { providers in
            handleGalleryDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private func imageSlot(index: Int) -> some View {
        ImageSlotView(
            imageData: showcaseImages[index],
            slotWidth: ShowcaseLayout.slotWidth,
            slotHeight: ShowcaseLayout.slotHeight,
            isSelected: mediaState.selectedImageIndex == index,
            tintColor: themeColor,
            onRemove: { 
                showcaseImages.remove(at: index)
                mediaState.clampSelection(for: showcaseImages)
            },
            onPreview: { 
                mediaState.selectedImageIndex = index
                mediaState.fullScreenImageData = showcaseImages[index]
            },
            onDrop: { providers in handleGalleryDrop(providers: providers, at: index) },
            onDragStart: { self.mediaState.draggedImageIndex = index }
        )
    }

    private func handleGalleryDrop(providers: [NSItemProvider], at index: Int? = nil) {
        if let sourceIndex = mediaState.draggedImageIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                let item = showcaseImages.remove(at: sourceIndex)
                let targetIndex = min(index ?? showcaseImages.count, showcaseImages.count)
                showcaseImages.insert(item, at: targetIndex)
                mediaState.selectedImageIndex = targetIndex
                mediaState.clampSelection(for: showcaseImages)
                HapticService.shared.playLight()
            }
            mediaState.draggedImageIndex = nil
            return
        }

        let remainingSlots = max(0, PromptMediaImportPipeline.maxSlots - showcaseImages.count)
        guard remainingSlots > 0 else {
            showImageImportWarning(.slotsFull)
            return
        }

        for provider in providers.prefix(remainingSlots) {
            PromptMediaImportPipeline.loadRawData(from: provider) { rawData in
                guard let rawData else {
                    showImageImportWarning(.unsupported)
                    return
                }
                enqueueImportedImageData(rawData, at: index)
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
        
        let remainingSlots = max(0, PromptMediaImportPipeline.maxSlots - self.showcaseImages.count)
        guard remainingSlots > 0 else {
            self.showImageImportWarning(.slotsFull)
            return
        }

        let urls = Array(panel.urls.prefix(remainingSlots))
        for url in urls {
            if let data = try? Data(contentsOf: url) {
                self.enqueueImportedImageData(data, at: nil)
            }
        }
    }

    private func enqueueImportedImageData(_ rawData: Data, at index: Int?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PromptMediaImportPipeline.optimizeImageData(rawData)
            switch result {
            case .failure(let failure):
                self.showImageImportWarning(failure)
            case .success(let optimized):
                DispatchQueue.main.async {
                    withAnimation(.spring()) {
                        guard self.showcaseImages.count < PromptMediaImportPipeline.maxSlots else {
                            self.showImageImportWarning(.slotsFull)
                            return
                        }

                        if let target = index, target < self.showcaseImages.count {
                            self.showcaseImages.insert(optimized, at: target)
                            self.mediaState.selectedImageIndex = target
                        } else {
                            self.showcaseImages.append(optimized)
                            self.mediaState.selectedImageIndex = self.showcaseImages.count - 1
                        }
                        self.mediaState.clampSelection(for: self.showcaseImages)
                    }
                    HapticService.shared.playSuccess()
                }
            }
        }
    }

    private func showImageImportWarning(_ failure: PromptMediaImportFailure) {
        let message = PromptMediaImportPipeline.localizedMessage(for: failure, language: preferences.language)
        DispatchQueue.main.async {
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
}
