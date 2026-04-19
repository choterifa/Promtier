//
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
                                    Text("#\(tag)")
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

