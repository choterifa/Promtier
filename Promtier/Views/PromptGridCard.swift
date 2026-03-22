//
//  PromptGridCard.swift
//  Promtier
//
//  VISTA: Card tipo grid (estilo RemNote) para mostrar prompts con imágenes y más detalles
//

import SwiftUI
import UniformTypeIdentifiers

struct PromptGridCard: View {
    let prompt: Prompt
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: (() -> Void)?
    let onHover: (Bool) -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @State private var isTargetedForDrop = false
    @State private var showcaseImagePaths: [String] = []
    
    // Cached Regex patterns
    static let bracketRegex = try? NSRegularExpression(pattern: "[\\{\\}\\[\\]\\(\\)]", options: [])
    static let variableRegex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}", options: [])
    
    private var highlightedContent: AttributedString {
        let previewText = String(prompt.content.prefix(250))
        var attrString = AttributedString(previewText)
        
        if let bracketRegex = Self.bracketRegex {
            let nsRange = NSRange(previewText.startIndex..., in: previewText)
            let matches = bracketRegex.matches(in: previewText, options: [], range: nsRange)
            for match in matches {
                if let range = Range(match.range, in: attrString) {
                    attrString[range].foregroundColor = currentCategoryColor.opacity(0.8)
                }
            }
        }
        
        if let variableRegex = Self.variableRegex {
            let nsRange = NSRange(previewText.startIndex..., in: previewText)
            let matches = variableRegex.matches(in: previewText, options: [], range: nsRange)
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: attrString) {
                    attrString[range].foregroundColor = .blue
                    attrString[range].font = .system(size: 13 * preferences.fontSize.scale, weight: .bold)
                    attrString[range].backgroundColor = Color.blue.opacity(0.08)
                }
            }
        }
        
        return attrString
    }
    
    private var variableCount: Int { prompt.extractTemplateVariables().count }
    
    private var currentCategoryColor: Color {
        if let folder = prompt.folder {
            if let customFolder = promptService.folders.first(where: { $0.name == folder }) {
                return Color(hex: customFolder.displayColor)
            }
        }
        return .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Title and Category
            HStack(alignment: .top) {
                if batchService.isSelectionModeActive {
                    Button(action: {
                        batchService.toggleSelection(for: prompt.id)
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: batchService.selectedPromptIds.contains(prompt.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(batchService.selectedPromptIds.contains(prompt.id) ? .blue : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
                
                Text(prompt.title)
                    .font(.system(size: 15 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let folder = prompt.folder, !folder.isEmpty {
                    let color = currentCategoryColor
                    Text(folder)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            
            // Image Preview (if any)
            if !showcaseImagePaths.isEmpty, let firstPath = showcaseImagePaths.first {
                let url = ImageStore.shared.url(forRelativePath: firstPath)
                DownsampledImageURLView(
                    imageURL: url,
                    cacheKey: "\(prompt.id.uuidString):grid:0:300:\(firstPath)",
                    maxPixelSize: 300,
                    contentMode: .fill
                )
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            
            // Description / Content Snippet
            VStack(alignment: .leading, spacing: 6) {
                if let desc = prompt.promptDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12 * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.75))
                        .lineLimit(2)
                }
                
                Text(highlightedContent)
                    .font(.system(size: 13 * preferences.fontSize.scale))
                    .foregroundColor(.secondary.opacity(0.9))
                    .lineLimit(showcaseImagePaths.isEmpty ? 4 : 2)
            }
            .padding(14)
            
            Spacer(minLength: 0)
            
            // Footer: Indicators and Actions
            HStack(spacing: 8) {
                if prompt.useCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 8))
                        Text("\(prompt.useCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
                
                if variableCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "cube.transparent.fill")
                            .font(.system(size: 8))
                        Text("\(variableCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.blue.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
                
                Spacer()
                
                if let onCopy = onCopy {
                    Button(action: {
                        onCopy()
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary.opacity(isHovered || isSelected ? 0.9 : 0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(isHovered || isSelected ? 0.05 : 0))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("copy".localized(for: preferences.language))
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.01))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.03)), alignment: .top)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected || isHovered ? currentCategoryColor.opacity(0.06) : Color.clear)
                        .blur(radius: isHovered ? 12 : 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorderColor, lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: 8, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            if batchService.isSelectionModeActive {
                batchService.toggleSelection(for: prompt.id)
                HapticService.shared.playLight()
            } else {
                onTap()
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if !batchService.isSelectionModeActive {
                    onDoubleTap()
                }
            }
        )
        .onHover { hovering in
            onHover(hovering)
        }
        .task {
            if prompt.showcaseImageCount > 0 {
                showcaseImagePaths = await promptService.fetchShowcaseImagePaths(byId: prompt.id)
            }
        }
    }
    
    private var cardBackgroundColor: Color {
        let isBatchSelected = batchService.selectedPromptIds.contains(prompt.id)
        if isBatchSelected { return Color.blue.opacity(0.12) }
        else if isSelected { return Color.blue.opacity(0.05) }
        else if isHovered { return Color.primary.opacity(0.04) }
        else { return Color.primary.opacity(0.02) }
    }
    
    private var cardBorderColor: Color {
        if isSelected { return currentCategoryColor.opacity(0.5) }
        else if isHovered { return currentCategoryColor.opacity(0.2) }
        else { return Color.primary.opacity(0.06) }
    }
}
