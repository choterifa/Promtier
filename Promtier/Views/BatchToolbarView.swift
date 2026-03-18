import SwiftUI

struct BatchToolbarView: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var batchService: BatchOperationsService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var showingFolderPicker = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Contador y Deseleccionar
            HStack(spacing: 8) {
                Text("\(batchService.selectedPromptIds.count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.blue))
                
                Text("seleccionados")
                    .font(.system(size: 13, weight: .bold))
            }
            
            Spacer()
            
            // Acciones
            HStack(spacing: 12) {
                // Seleccionar Todos
                Button(action: {
                    batchService.selectAll(from: promptService.filteredPrompts)
                    HapticService.shared.playLight()
                }) {
                    Label("Todos", systemImage: "checkmark.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Seleccionar todos los visibles")
                
                Divider().frame(height: 16)
                
                // Mover a Carpeta
                Button(action: { showingFolderPicker = true }) {
                    Label("Mover", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingFolderPicker) {
                    FolderPickerView { folderName in
                        moveSelected(to: folderName)
                        showingFolderPicker = false
                    }
                }
                
                // Eliminar (a la papelera)
                Button(action: { showingDeleteConfirmation = true }) {
                    Label("Papelera", systemImage: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .confirmationDialog("¿Mover \(batchService.selectedPromptIds.count) prompts a la papelera?", isPresented: $showingDeleteConfirmation) {
                    Button("Mover a la papelera", role: .destructive) {
                        deleteSelected()
                    }
                    Button("Cancelar", role: .cancel) { }
                }
            }
            
            Divider().frame(height: 16)
            
            // Cerrar Selección
            Button(action: {
                withAnimation(.spring()) {
                    batchService.clearSelection()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func moveSelected(to folderName: String?) {
        for id in batchService.selectedPromptIds {
            if let prompt = promptService.prompts.first(where: { $0.id == id }) {
                var updated = prompt
                updated.folder = folderName
                _ = promptService.updatePrompt(updated)
            }
        }
        batchService.clearSelection()
        HapticService.shared.playSuccess()
    }
    
    private func deleteSelected() {
        for id in batchService.selectedPromptIds {
            if let prompt = promptService.prompts.first(where: { $0.id == id }) {
                _ = promptService.deletePrompt(prompt)
            }
        }
        batchService.clearSelection()
        HapticService.shared.playSuccess()
    }
}

struct FolderPickerView: View {
    @EnvironmentObject var promptService: PromptService
    var onSelect: (String?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mover a...")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 2) {
                    Button(action: { onSelect(nil) }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Sin categoría")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(promptService.folders) { folder in
                        Button(action: { onSelect(folder.name) }) {
                            HStack {
                                Image(systemName: folder.icon ?? "folder.fill")
                                    .foregroundColor(Color(hex: folder.displayColor))
                                Text(folder.name)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 180)
        .frame(maxHeight: 250)
    }
}
