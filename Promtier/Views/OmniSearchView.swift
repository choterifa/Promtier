//
//  OmniSearchView.swift
//  Promtier
//
//  VISTA: Buscador global tipo Spotlight
//

import SwiftUI
import AppKit

struct OmniSearchView: View {
    @EnvironmentObject var manager: OmniSearchManager
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool
    
    private var filteredPrompts: [Prompt] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            // Mostrar últimos usados o favoritos si no hay búsqueda
            return Array(promptService.prompts
                .sorted(by: { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) })
                .prefix(8))
        } else {
            let searchTerms = trimmedQuery.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            let scored = promptService.prompts.compactMap { prompt -> (Prompt, Int)? in
                var score = 0
                let title = prompt.title.lowercased()
                let content = prompt.content.lowercased()
                let desc = (prompt.promptDescription ?? "").lowercased()
                
                for term in searchTerms {
                    if title.contains(term) {
                        score += 100
                        if title.hasPrefix(term) { score += 50 }
                    }
                    if desc.contains(term) { score += 40 }
                    if content.contains(term) { score += 20 }
                }
                
                guard score > 0 else { return nil }
                
                // Bonus por reciencia
                if let lastUsed = prompt.lastUsedAt, lastUsed > Date().addingTimeInterval(-86400 * 7) {
                    score += 10
                }
                
                return (prompt, score)
            }
            
            return Array(scored
                .sorted(by: { $0.1 > $1.1 })
                .map { $0.0 }
                .prefix(12))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barra de Búsqueda Premium
            HStack(spacing: 15) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
                    .shadow(color: preferences.isHaloEffectEnabled ? .blue.opacity(0.3) : .clear, radius: 4)
                
                TextField("gt_search_prompts".localized(for: preferences.language), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                    .focused($isFocused)
                    .onExitCommand {
                        manager.hide()
                    }
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                    .onSubmit {
                        if !filteredPrompts.isEmpty {
                            copyAndClose(filteredPrompts[selectedIndex])
                        }
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                // Badge de atajo
                Text("Esc")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 22)
            .background(Color.primary.opacity(0.03))
            
            if !filteredPrompts.isEmpty {
                Divider().opacity(0.1)
                
                // Lista de Resultados
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                                OmniSearchRow(
                                    prompt: prompt,
                                    isSelected: selectedIndex == index,
                                    onTap: {
                                        copyAndClose(prompt)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(12)
                    }
                    .background(Color.black.opacity(0.001))
                    .frame(maxHeight: 380)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            } else if !query.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.2))
                    Text("no_results".localized(for: preferences.language))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
            
            // Footer Informativo
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("move_selection".localized(for: preferences.language))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "return")
                    Text("copy_and_close".localized(for: preferences.language))
                }
                
                Spacer()
                
                Text("Promtier Spotlight")
                    .font(.system(size: 10, weight: .black))
                    .italic()
                    .opacity(0.3)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.6))
            .padding(.horizontal, 25)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.04))
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            // Delay extra para asegurar que la ventana es KEY antes de enfocar el TextField
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OmniSearchOpened"))) { _ in
            query = ""
            selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OmniSearchMove"))) { notification in
            guard let direction = notification.object as? String else { return }
            let count = filteredPrompts.count
            
            if direction == "down" {
                if selectedIndex < count - 1 {
                    selectedIndex += 1
                    HapticService.shared.playLight()
                }
            } else if direction == "up" {
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    HapticService.shared.playLight()
                }
            }
        }
    }
    
    private func copyAndClose(_ prompt: Prompt) {
        ClipboardService.shared.copyToClipboard(prompt.content)
        HapticService.shared.playSuccess()
        if PreferencesManager.shared.soundEnabled {
            SoundService.shared.playMagicSound()
        }
        manager.hide()
    }
}

// MARK: - OmniSearchRow
struct OmniSearchRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let onTap: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icono del Prompt
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: prompt.icon ?? "doc.text.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? .white : (preferences.isHaloEffectEnabled ? .blue : .primary.opacity(0.8)))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if let desc = prompt.promptDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    } else {
                        Text(prompt.content)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                } else if isHovered {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Extension para identificar la vista root en el NSPanel
extension NSView {
    var hostingView: NSHostingView<AnyView>? {
        return self as? NSHostingView<AnyView>
    }
}
