//
//  NewPromptHeaderView.swift
//  Promtier
//
//  Header bar for NewPromptView
//

import SwiftUI

struct NewPromptHeaderView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager

    // Data dependencies
    let title: String
    let content: String
    let promptDescription: String
    let showcaseImages: [Data]
    let originalPrompt: Prompt?
    let prompt: Prompt?
    let currentCategoryColor: Color
    let themeColor: Color
    let hasUnsavedChanges: Bool

    // State bindings passed from parent
    @Binding var showingCloseAlert: Bool
    @Binding var showingVersionHistory: Bool
    @Binding var showingPremiumFor: String?
    @Binding var isPinned: Bool
    @Binding var branchMessage: String?

    // Actions
    let discardChanges: () -> Void
    let saveCurrentDraft: () -> Void
    let branchPrompt: () -> Void
    let savePrompt: () -> Void
    let closePopover: () -> Void

    // Local Hover States to prevent parent re-renders
    @State private var isHoveringCancel = false
    @State private var isHoveringHistory = false
    @State private var isHoveringZen = false
    @State private var isHoveringPin = false
    @State private var isHoveringBranch = false
    @State private var isHoveringSave = false

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                Button(action: {
                    if hasUnsavedChanges {
                        showingCloseAlert = true
                    } else {
                        discardChanges()
                    }
                }) {
                    Text("cancel".localized(for: preferences.language))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveringCancel ? currentCategoryColor.opacity(0.12) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCancel = $0 }
                .animation(.easeInOut(duration: 0.2), value: isHoveringCancel)

                Spacer()

                HStack(spacing: 12) {
                    if originalPrompt != nil && !(originalPrompt?.versionHistory.isEmpty ?? true) {
                        Button(action: {
                            if preferences.isPremiumActive {
                                showingVersionHistory = true
                            } else {
                                showingPremiumFor = "Version History"
                            }
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeColor)
                                .frame(width: 32, height: 32)
                                .background(themeColor.opacity(isHoveringHistory ? 0.25 : 0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringHistory = $0 }
                        .animation(.easeInOut(duration: 0.2), value: isHoveringHistory)
                        .help("Ver historial")
                        .transition(.opacity)
                    }

                    Button(action: {
                        saveCurrentDraft()
                        FloatingZenManager.shared.show(
                            title: title,
                            promptDescription: promptDescription,
                            content: content,
                            showcaseImages: showcaseImages,
                            promptId: originalPrompt?.id ?? prompt?.id,
                            isEditing: true
                        )
                        closePopover()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeColor)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(themeColor.opacity(isHoveringZen ? 0.25 : 0.1)))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringZen = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringZen)
                    .help("Floating Zen Mode")

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isPinned.toggle()
                            menuBarManager.isModalActive = isPinned
                        }
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isPinned ? .white : themeColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(
                                    isPinned
                                        ? themeColor
                                        : themeColor.opacity(isHoveringPin ? 0.25 : 0.1)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPin = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringPin)
                    .animation(.easeInOut(duration: 0.2), value: isPinned)
                    .help(isPinned ? "Desfijar ventana (Cmd+L)" : "Fijar ventana (Cmd+L)")
                    .keyboardShortcut("l", modifiers: .command)

                    if (originalPrompt ?? prompt) != nil {
                        Button(action: {
                            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                branchPrompt()
                            } else {
                                HapticService.shared.playError()
                                withAnimation { self.branchMessage = "required_fields".localized(for: preferences.language) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation { if self.branchMessage == "required_fields".localized(for: preferences.language) { self.branchMessage = nil } }
                                }
                            }
                        }) {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeColor)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(themeColor.opacity(isHoveringBranch ? 0.25 : 0.1)))
                        }
                        .buttonStyle(.plain)
                        .onHover { isHoveringBranch = $0 }
                        .animation(.easeInOut(duration: 0.2), value: isHoveringBranch)
                        .help("create_branch".localized(for: preferences.language))
                    }

                    Button(action: {
                        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            savePrompt()
                        } else {
                            HapticService.shared.playError()
                            withAnimation { self.branchMessage = "required_fields".localized(for: preferences.language) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation { if self.branchMessage == "required_fields".localized(for: preferences.language) { self.branchMessage = nil } }
                            }
                        }
                    }) {
                        Text(prompt != nil ? "save".localized(for: preferences.language) : "create".localized(for: preferences.language))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : (isHoveringSave ? currentCategoryColor.opacity(0.85) : (preferences.isHaloEffectEnabled ? currentCategoryColor : .blue)))
                                    .shadow(color: title.isEmpty || content.isEmpty ? .clear : (preferences.isHaloEffectEnabled ? (isHoveringSave ? currentCategoryColor.opacity(0.4) : currentCategoryColor.opacity(0.2)) : .clear), radius: isHoveringSave ? 8 : 4, y: isHoveringSave ? 4 : 2)
                            )
                            .scaleEffect(isHoveringSave ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringSave = $0 }
                    .animation(.easeInOut(duration: 0.2), value: isHoveringSave)
                    .disabled(title.isEmpty || content.isEmpty)
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            .padding(.horizontal, 16)

            // Título central (Ajustado para estar siempre al centro real)
            VStack(spacing: 2) {
                Text(prompt != nil ? "edit_prompt".localized(for: preferences.language) : "new_prompt".localized(for: preferences.language))
                    .font(.system(size: 15, weight: .bold))
                Text(prompt != nil ? "update_details".localized(for: preferences.language) : "create_tool".localized(for: preferences.language))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .allowsHitTesting(false) // Dejar que los clics pasen a los botones si hubiera solapamiento
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
