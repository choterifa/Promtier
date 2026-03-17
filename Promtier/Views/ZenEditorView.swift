//
//  ZenEditorView.swift
//  Promtier
//
//  VISTA: Editor minimalista a pantalla completa
//

import SwiftUI

struct ZenEditorView: View {
    @Binding var title: String
    @Binding var content: String
    let onDone: () -> Void
    
    @EnvironmentObject var preferences: PreferencesManager
    @FocusState private var isEditorFocused: Bool
    @State private var insertionRequest: String? = nil
    @State private var replaceSnippetRequest: String? = nil
    @State private var showSnippets: Bool = false
    @State private var snippetSearchQuery: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header minimalista
            HStack {
                TextField("Título del prompt...", text: $title)
                    .font(.system(size: 24 * preferences.fontSize.scale, weight: .bold))
                    .textFieldStyle(.plain)
                
                Spacer()
                
                Button(action: { insertionRequest = "{{variable}}" }) {
                    HStack {
                        Image(systemName: "curlybraces")
                        Text("Añadir Variable")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                Button(action: onDone) {
                    HStack {
                        Text("Salir del Modo Zen")
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(32)
            
            // Editor Principal
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Escribe tu prompt aquí con total libertad...")
                        .font(.system(size: 18 * preferences.fontSize.scale))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                
                HighlightedEditor(
                    text: $content,
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    fontSize: 18 * preferences.fontSize.scale,
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery
                )
                .focused($isEditorFocused)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            
            // Footer con info
            HStack {
                HStack(spacing: 16) {
                    Label("\(content.count) caracteres", systemImage: "character.cursor.ibeam")
                    Label("\(content.split(separator: " ").count) palabras", systemImage: "text.word.spacing")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Auto-guardado activo")
                    .font(.system(size: 12))
                    .foregroundColor(.green.opacity(0.8))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.primary.opacity(0.02))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isEditorFocused = true
        }
    }
}
