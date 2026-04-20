import SwiftUI

struct SearchHeaderView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var batchService: BatchOperationsService
    
    @Binding var isSearchFocused: Bool
    @State private var isPlusHovered = false
    @State private var isBatchHovered = false
    @State private var isSettingsHovered = false
    @State private var isViewToggleHovered = false
    
    var onNewPrompt: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // View Toggle (Grid/List)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        preferences.isGridView.toggle()
                        if preferences.autoHideSidebarInGallery {
                            preferences.showSidebar = !preferences.isGridView
                        }
                    }
                }) {
                    Image(systemName: preferences.isGridView ? "list.dash.header.rectangle" : "text.below.photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(preferences.isGridView ? .blue : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(preferences.isGridView ? Color.blue.opacity(isViewToggleHovered ? 0.15 : 0.1) : Color.primary.opacity(isViewToggleHovered ? 0.08 : 0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(preferences.isGridView ? Color.blue.opacity(isViewToggleHovered ? 0.3 : 0.15) : Color.primary.opacity(isViewToggleHovered ? 0.12 : 0.06), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { isViewToggleHovered = $0 }
                .help(preferences.isGridView ? "List View" : "Grid View")

                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)

                    TextField("search_placeholder".localized(for: preferences.language), text: $promptService.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15 * preferences.fontSize.scale))
                        .disableAutocorrection(true)
                        .onChange(of: promptService.searchQuery) { _, newValue in
                            if newValue.count > 40 {
                                promptService.searchQuery = String(newValue.prefix(40))
                            }
                        }

                    if !promptService.searchQuery.isEmpty {
                        Button(action: { promptService.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )

                // Actions
                HStack(spacing: 10) {
                    Button(action: onNewPrompt) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isPlusHovered ? Color.blue.opacity(0.85) : Color.blue)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isPlusHovered = $0 }
                    .help("new_prompt".localized(for: preferences.language) + " (N)")

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            batchService.isSelectionModeActive.toggle()
                            if !batchService.isSelectionModeActive {
                                batchService.clearSelection()
                            }
                        }
                        HapticService.shared.playLight()
                    }) {
                        Image(systemName: batchService.isSelectionModeActive ? "checkmark.circle.fill" : "list.bullet.indent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(batchService.isSelectionModeActive ? .blue : .primary.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(batchService.isSelectionModeActive ? Color.blue.opacity(0.12) : Color.primary.opacity(isBatchHovered ? 0.08 : 0.04))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isBatchHovered = $0 }

                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(isSettingsHovered ? 0.08 : 0.04))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isSettingsHovered = $0 }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
