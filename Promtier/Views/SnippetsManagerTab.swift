//
//  SnippetsManagerTab.swift
//  Promtier
//
//  VISTA: Administrador de Snippets para Promtier Premium
//

import SwiftUI

struct SnippetsManagerTab: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var showingAddSheet = false
    @State private var editingSnippet: Snippet?
    
    var body: some View {
        VStack(spacing: 32) {
            SettingsSection(title: "quick_snippets", icon: "text.quote") {
                VStack(spacing: 0) {
                    // Header de la sección
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("my_snippets")
                                .font(.system(size: 14 * preferences.fontSize.scale, weight: .semibold))
                            Text("snippets_desc")
                                .font(.system(size: 12 * preferences.fontSize.scale))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingAddSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("add")
                            }
                            .font(.system(size: 12 * preferences.fontSize.scale, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Lista de Snippets
                    if preferences.snippets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "text.badge.xmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("no_snippets_configured")
                                .font(.system(size: 13 * preferences.fontSize.scale))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(preferences.snippets.indices, id: \.self) { index in
                                if index < preferences.snippets.count {
                                    SnippetManagerListItem(
                                        snippet: preferences.snippets[index],
                                        index: index,
                                        editingSnippet: $editingSnippet
                                    )
                                }
                            }
                        }
                        .background(Color.gray.opacity(0.05))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SnippetEditorSheet(snippet: nil) { newSnippet in
                preferences.snippets.append(newSnippet)
                showingAddSheet = false
            } onCancel: {
                showingAddSheet = false
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorSheet(snippet: snippet) { updatedSnippet in
                if let index = preferences.snippets.firstIndex(where: { $0.id == updatedSnippet.id }) {
                    preferences.snippets[index] = updatedSnippet
                }
                editingSnippet = nil
            } onCancel: {
                editingSnippet = nil
            }
        }
    }
}

private struct SnippetManagerListItem: View {
    let snippet: Snippet
    let index: Int
    @Binding var editingSnippet: Snippet?
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet.title)
                        .font(.system(size: 13 * preferences.fontSize.scale, weight: .semibold))
                    
                    HStack(spacing: 4) {
                        Text("/")
                            .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(snippet.shortcut)
                            .font(.system(size: 11 * preferences.fontSize.scale, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Acciones
                HStack(spacing: 12) {
                    Button(action: { editingSnippet = snippet }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("edit_action", comment: ""))
                    
                    Button(action: {
                        withAnimation {
                            if index < preferences.snippets.count {
                                preferences.snippets.remove(at: index)
                            }
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("delete_action", comment: ""))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            if index < preferences.snippets.count - 1 {
                Divider()
                    .padding(.leading, 20)
            }
        }
    }
}

private struct SnippetEditorSheet: View {
    let snippet: Snippet?
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var shortcut: String = ""
    @State private var content: String = ""
    
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(snippet == nil ? NSLocalizedString("new_snippet", comment: "") : NSLocalizedString("edit_snippet", comment: ""))
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Formulario
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("title_label", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField(NSLocalizedString("title_placeholder", comment: ""), text: $title)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("command_shortcut", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        Text("/")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        TextField(NSLocalizedString("command_placeholder", comment: ""), text: $shortcut)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
                    
                    Text(NSLocalizedString("command_rule", comment: ""))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("content_label", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $content)
                        .font(.system(size: 13))
                        .frame(height: 120)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
                }
            }
            .padding(20)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Text(NSLocalizedString("cancel", comment: ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                let isValid = !title.isEmpty && !shortcut.isEmpty && !content.isEmpty && !shortcut.contains(" ")
                
                Button(action: {
                    var finalSnippet = Snippet(title: title, content: content, shortcut: shortcut)
                    if let existing = snippet {
                        finalSnippet.id = existing.id
                    }
                    onSave(finalSnippet)
                }) {
                    Text(NSLocalizedString("save", comment: ""))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isValid ? Color.blue : Color.gray.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .frame(width: 400)
        .onAppear {
            if let existing = snippet {
                title = existing.title
                shortcut = existing.shortcut
                content = existing.content
            }
        }
    }
}
