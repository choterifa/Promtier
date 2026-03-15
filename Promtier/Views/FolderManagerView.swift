//
//  FolderManagerView.swift
//  Promtier
//
//  VISTA: Gestión de carpetas de organización
//  Created by Carlos on 15/03/26.
//

import SwiftUI

struct FolderManagerView: View {
    @EnvironmentObject var promptService: PromptServiceSimple
    @Environment(\.dismiss) private var dismiss
    
    @State private var folders: [String] = []
    @State private var newFolderName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingFolder: String?
    
    var body: some View {
        NavigationView {
            VStack {
                // Lista de carpetas
                List {
                    ForEach(folders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            
                            Text(folder)
                            
                            Spacer()
                            
                            // Contador de prompts en esta carpeta
                            let count = promptService.prompts.filter { $0.folder == folder }.count
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            
                            // Botones de acción
                            Menu {
                                Button("Editar nombre") {
                                    editingFolder = folder
                                    newFolderName = folder
                                }
                                
                                Button("Ver prompts", role: nil) {
                                    // TODO: Implementar navegación a prompts de esta carpeta
                                }
                                
                                Divider()
                                
                                Button("Eliminar", role: .destructive) {
                                    deleteFolder(folder)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
                
                // Sección para agregar nueva carpeta
                VStack(spacing: 16) {
                    HStack {
                        TextField("Nombre de la nueva carpeta", text: $newFolderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Agregar") {
                            addFolder()
                        }
                        .disabled(newFolderName.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if editingFolder != nil {
                        HStack {
                            TextField("Nuevo nombre", text: $newFolderName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Guardar") {
                                updateFolder()
                            }
                            .disabled(newFolderName.isEmpty)
                            .buttonStyle(.borderedProminent)
                            
                            Button("Cancelar") {
                                editingFolder = nil
                                newFolderName = ""
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Gestión de Carpetas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .onAppear {
                loadFolders()
            }
            .alert("Información", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Métodos
    
    private func loadFolders() {
        let uniqueFolders = Set(promptService.prompts.compactMap { $0.folder })
        folders = Array(uniqueFolders).sorted()
    }
    
    private func addFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showAlert("El nombre de la carpeta no puede estar vacío")
            return
        }
        
        guard !folders.contains(trimmedName) else {
            showAlert("Ya existe una carpeta con ese nombre")
            return
        }
        
        folders.append(trimmedName)
        folders.sort()
        newFolderName = ""
        
        showAlert("Carpeta '\(trimmedName)' agregada correctamente")
    }
    
    private func updateFolder() {
        guard let editingFolder = editingFolder else { return }
        
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            showAlert("El nombre de la carpeta no puede estar vacío")
            return
        }
        
        guard !folders.contains(trimmedName) || trimmedName == editingFolder else {
            showAlert("Ya existe una carpeta con ese nombre")
            return
        }
        
        // Actualizar todos los prompts que usan esta carpeta
        for i in 0..<promptService.prompts.count {
            if promptService.prompts[i].folder == editingFolder {
                promptService.prompts[i].folder = trimmedName
            }
        }
        
        // Actualizar lista de carpetas
        if let index = folders.firstIndex(of: editingFolder) {
            folders[index] = trimmedName
        }
        folders.sort()
        
        self.editingFolder = nil
        newFolderName = ""
        
        showAlert("Carpeta renombrada correctamente")
    }
    
    private func deleteFolder(_ folder: String) {
        let promptsInFolder = promptService.prompts.filter { $0.folder == folder }
        
        if !promptsInFolder.isEmpty {
            showAlert("No se puede eliminar la carpeta '\(folder)' porque contiene \(promptsInFolder.count) prompts")
            return
        }
        
        folders.removeAll { $0 == folder }
        showAlert("Carpeta '\(folder)' eliminada correctamente")
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            deleteFolder(folder)
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

#Preview {
    FolderManagerView()
        .environmentObject(PromptServiceSimple())
}
