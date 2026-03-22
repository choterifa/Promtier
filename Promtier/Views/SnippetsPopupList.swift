//
//  SnippetsPopupList.swift
//  Promtier
//
//  VISTA: Lista flotante para autocompletar snippets
//

import SwiftUI

struct SnippetsPopupList: View {
    let query: String
    @Binding var selectedIndex: Int
    @Binding var triggerSelection: Bool
    let onSelect: (Snippet) -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    
    var filteredSnippets: [Snippet] {
        if query.isEmpty {
            return preferences.snippets
        } else {
            return preferences.snippets.filter {
                $0.shortcut.localizedCaseInsensitiveContains(query) ||
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Snippets")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ESC para cancelar")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            if filteredSnippets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No hay snippets para '\(query)'")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(filteredSnippets.enumerated()), id: \.element.id) { index, snippet in
                                SnippetRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex,
                                    action: { onSelect(snippet) }
                                )
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 250)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // Add implicit animation to the row when selection state changes
        .onChange(of: selectedIndex) { _, newIndex in
            if newIndex >= filteredSnippets.count && !filteredSnippets.isEmpty {
                selectedIndex = filteredSnippets.count - 1
            }
        }
        .onChange(of: triggerSelection) { _, triggered in
            if triggered {
                if !filteredSnippets.isEmpty {
                    let clampedIndex = min(max(0, selectedIndex), filteredSnippets.count - 1)
                    onSelect(filteredSnippets[clampedIndex])
                }
                triggerSelection = false
            }
        }
        // KeyEvent handler local para navegación de flechas
        .onAppear {
            self.selectedIndex = 0
        }
        .onChange(of: query) { _, _ in
            self.selectedIndex = 0
        }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.05))
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                    
                    Text("/")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(snippet.shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // Asegura que toda la fila sea clickeable
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            // Implicit animation
            .animation(.none, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
