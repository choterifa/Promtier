import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

# We need to extract:
# 1. PromptTagsEditorView
# 2. PromptAppTargetsView
# 3. PromptImageShowcaseView

import os
os.makedirs("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views", exist_ok=True)

tags_code = """//
//  PromptTagsEditorView.swift
//  Promtier
//

import SwiftUI

struct PromptTagsEditorView: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    @Binding var showingTagEditor: Bool
    
    let preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
                Text("tags".localized(for: preferences.language).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingTagEditor.toggle()
                    }
                }) {
                    Image(systemName: showingTagEditor ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(showingTagEditor ? .red.opacity(0.8) : .blue.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            
            if showingTagEditor || !tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if showingTagEditor {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.secondary.opacity(0.5))
                            TextField("add_tag_placeholder".localized(for: preferences.language), text: $newTag)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12 * preferences.fontSize.scale))
                                .onSubmit {
                                    let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    if !tag.isEmpty && !tags.contains(tag) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            tags.append(tag)
                                            newTag = ""
                                        }
                                        HapticService.shared.playLight()
                                    }
                                }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    
                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text("#\\(tag)")
                                        .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            tags.removeAll { $0 == tag }
                                        }
                                        HapticService.shared.playLight()
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.02)))
            }
        }
    }
}

// FlowLayout helper if not exists globally
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        if let firstRow = rows.first, let firstView = firstRow.first {
            height = firstView.dimensions(in: .unspecified).height
        }
        return CGSize(width: proposal.width ?? 0, height: height * CGFloat(rows.count) + spacing * CGFloat(max(0, rows.count - 1)))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for view in row {
                let size = view.dimensions(in: .unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRow = 0
        var currentX: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for view in subviews {
            let size = view.dimensions(in: .unspecified)
            if currentX + size.width > maxWidth && !rows[currentRow].isEmpty {
                currentRow += 1
                rows.append([])
                currentX = 0
            }
            rows[currentRow].append(view)
            currentX += size.width + spacing
        }
        return rows
    }
}
"""
with open("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptTagsEditorView.swift", "w") as f:
    f.write(tags_code)

targets_code = """//
//  PromptAppTargetsView.swift
//  Promtier
//

import SwiftUI

struct PromptAppTargetsView: View {
    @Binding var targetAppBundleIDs: [String]
    @Binding var showingAppPicker: Bool
    
    let preferences: PreferencesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
                Text("app_association".localized(for: preferences.language).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Button(action: {
                    showingAppPicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("add_app".localized(for: preferences.language))
            }
            
            if !targetAppBundleIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("active_in_apps".localized(for: preferences.language))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    ForEach(targetAppBundleIDs, id: \.self) { bundleID in
                        HStack {
                            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                
                                Text(FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: ""))
                                    .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                            } else {
                                Image(systemName: "app.dashed")
                                    .frame(width: 16, height: 16)
                                Text(bundleID)
                                    .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    targetAppBundleIDs.removeAll { $0 == bundleID }
                                }
                                HapticService.shared.playLight()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.02)))
            } else {
                Text("available_globally".localized(for: preferences.language))
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 4)
            }
        }
        .popover(isPresented: $showingAppPicker, arrowEdge: .bottom) {
            SharedAppPicker { bundleID in
                if !targetAppBundleIDs.contains(bundleID) {
                    targetAppBundleIDs.append(bundleID)
                }
            }
        }
    }
}
"""
with open("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptAppTargetsView.swift", "w") as f:
    f.write(targets_code)

showcase_code = """//
//  PromptImageShowcaseView.swift
//  Promtier
//

import SwiftUI

struct PromptImageShowcaseView: View {
    @Binding var showcaseImages: [Data]
    @Binding var isDragging: Bool
    @Binding var draggedImageIndex: Int?
    @Binding var showingFullScreenImage: Data?
    @Binding var selectedImageIndex: Int
    @Binding var branchMessage: String?
    
    let preferences: PreferencesManager
    
    private enum ImageImportPolicy {
        static let maxInputBytes = 64 * 1024 * 1024
        static let maxSlots = 3
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.purple)
                Text("image_showcase".localized(for: preferences.language).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Button(action: importImagesDirectly) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.purple.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("add_image".localized(for: preferences.language))
            }
            
            imageGallery(width: 300)
                .padding(.horizontal, 4)
        }
    }
    
    private func imageGallery(width: CGFloat) -> some View {
        let slotWidth = (width - 52) / 3
        let slotHeight = slotWidth * 0.66
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<ImageImportPolicy.maxSlots, id: \.self) { index in
                    Group {
                        if index < showcaseImages.count {
                            DownsampledImageView(imageData: showcaseImages[index], maxSize: CGSize(width: slotWidth * 2, height: slotHeight * 2))
                                .frame(width: slotWidth, height: slotHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        selectedImageIndex = index
                                        showingFullScreenImage = showcaseImages[index]
                                    }
                                }
                                .contextMenu {
                                    Button("view_full_screen".localized(for: preferences.language)) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            selectedImageIndex = index
                                            showingFullScreenImage = showcaseImages[index]
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive, action: {
                                        withAnimation(.spring()) {
                                            showcaseImages.remove(at: index)
                                        }
                                    }) {
                                        Label("remove_image".localized(for: preferences.language), systemImage: "trash")
                                    }
                                }
                        } else {
                            ImageSlotView(
                                width: slotWidth,
                                height: slotHeight,
                                isDragging: $isDragging,
                                onDrop: { data in
                                    insertImage(data, at: index)
                                }
                            )
                        }
                    }
                }
            }
            
            if !showcaseImages.isEmpty {
                Text("image_showcase_hint".localized(for: preferences.language))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.top, 4)
            }
        }
    }
    
    private func insertImage(_ data: Data, at index: Int?) {
        if showcaseImages.count < ImageImportPolicy.maxSlots {
            if let targetIndex = index, targetIndex < showcaseImages.count {
                showcaseImages.insert(data, at: targetIndex)
            } else {
                showcaseImages.append(data)
            }
        } else {
            showImageImportWarning("image_import_slots_full".localized(for: preferences.language))
        }
    }
    
    private func importImagesDirectly() {
        DispatchQueue.main.async {
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
            DispatchQueue.global(qos: .userInitiated).async {
                for url in urls {
                    guard self.isAcceptableImageFile(url) else { continue }
                    if let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) {
                        DispatchQueue.main.async {
                            self.appendOptimizedImageData(data, at: nil)
                        }
                    }
                }
            }
        }
    }
    
    private func isAcceptableImageFile(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else {
            return false
        }
        return size <= ImageImportPolicy.maxInputBytes
    }
    
    private func appendOptimizedImageData(_ data: Data, at targetIndex: Int?) {
        Task {
            do {
                guard let nsImage = NSImage(data: data) else { throw URLError(.cannotDecodeRawData) }
                let optimizedData = try await ImageOptimizer.shared.optimizeForDraft(image: nsImage)
                
                await MainActor.run {
                    withAnimation(.spring()) {
                        if let index = targetIndex, index < self.showcaseImages.count {
                            self.showcaseImages.insert(optimizedData, at: index)
                        } else {
                            if self.showcaseImages.count < ImageImportPolicy.maxSlots {
                                self.showcaseImages.append(optimizedData)
                            } else {
                                self.showImageImportWarning("image_import_slots_full".localized(for: preferences.language))
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.showImageImportWarning("image_import_failed".localized(for: preferences.language))
                }
            }
        }
    }
    
    private func showImageImportWarning(_ message: String) {
        DispatchQueue.main.async {
            HapticService.shared.playError()
            withAnimation {
                branchMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                    if branchMessage == message {
                        branchMessage = nil
                    }
                }
            }
        }
    }
}
"""
with open("/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptImageShowcaseView.swift", "w") as f:
    f.write(showcase_code)
