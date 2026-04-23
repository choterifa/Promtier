//
//  CategorySidebar+Rows.swift
//  Promtier
//
//  Responsabilidad: Sub-vistas reutilizables para cada fila del sidebar —
//  PinnedFolderRow (fila anclada) y FolderRow (fila normal con Drag & Drop).
//  Ambas son componentes pasivos ("dumb views") que reciben datos y callbacks.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - PinnedFolderRow

struct PinnedFolderRow: View {
    let folder: Folder
    let count: Int
    let isSelected: Bool

    var onSelect: () -> Void
    var onRename: (String) -> Void
    var onEdit: () -> Void
    var onUnpin: () -> Void

    @EnvironmentObject private var preferences: PreferencesManager
    @EnvironmentObject private var menuBarManager: MenuBarManager

    var body: some View {
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: isSelected,
            isPinned: true,
            action: onSelect,
            isEditable: true,
            rawTitle: folder.name,
            onRename: onRename,
            onDoubleClickRow: onEdit
        )
        .transition(.move(edge: .leading).combined(with: .opacity))
        .contextMenu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { onUnpin() }
                HapticService.shared.playLight()
            } label: {
                Label("Quitar pin", systemImage: "pin.slash")
            }

            Divider()

            Button(action: onEdit) {
                Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
            }
        }
    }
}

// MARK: - FolderRow

struct FolderRow: View {
    let folder: Folder
    let count: Int
    let isSelected: Bool
    let isDropTarget: Bool
    let isReorderTarget: Bool
    var depth: Int = 0

    var onSelect: () -> Void
    var onRename: (String) -> Void
    var onEdit: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void
    var onDragStarted: () -> Void
    var onPromptMove: ([String], String) -> Void

    @EnvironmentObject private var preferences: PreferencesManager
    @EnvironmentObject private var promptService: PromptService
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var batchService: BatchOperationsService

    // Bindings for drop delegate
    @Binding var dropTargetFolderId: UUID?
    @Binding var draggedFolder: Folder?

    var body: some View {
        SidebarItem(
            title: LocalizedStringKey(folder.name),
            icon: folder.icon ?? "folder.fill",
            color: Color(hex: folder.displayColor),
            count: count,
            isSelected: isSelected,
            isDropTarget: isDropTarget,
            isReorderTarget: isReorderTarget,
            action: onSelect,
            isEditable: true,
            rawTitle: folder.name,
            onRename: onRename,
            onDoubleClickRow: onEdit,
            onDeleteSwipe: onDelete
        )
        .padding(.leading, CGFloat(depth * 14))
        .transition(.move(edge: .leading).combined(with: .opacity))
        .onDrag {
            onDragStarted()
            return NSItemProvider(object: folder.id.uuidString as NSString)
        }
        .onDrop(of: [.json, .plainText, .text], delegate: FolderSidebarDropDelegate(
            folder: folder,
            promptService: promptService,
            menuBarManager: menuBarManager,
            dropTargetFolderId: $dropTargetFolderId,
            draggedFolder: $draggedFolder,
            onPromptMove: onPromptMove
        ))
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if depth < 2 {
            Button {
                menuBarManager.parentFolderIdForNewCategory = folder.id
                menuBarManager.folderToEdit = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .folderManager
                }
            } label: {
                Label("new_subcategory".localized(for: preferences.language), systemImage: "folder.badge.plus")
            }
            Divider()
        }

        if preferences.pinnedFolderNames.count < 3 || preferences.isPinned(folder.name) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { onTogglePin() }
                HapticService.shared.playLight()
            } label: {
                Label(
                    preferences.isPinned(folder.name) ? "Quitar pin" : "Pinear categoría",
                    systemImage: preferences.isPinned(folder.name) ? "pin.slash" : "pin.fill"
                )
            }
            Divider()
        }

        Button(action: onEdit) {
            Label("edit".localized(for: preferences.language), systemImage: "square.and.pencil")
        }

        Button(role: .destructive, action: onDelete) {
            Label("delete".localized(for: preferences.language), systemImage: "trash")
        }
    }
}
