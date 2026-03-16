 //
//  NewPromptView.swift
//  Promtier
//
//  VISTA: Creación y edición de prompts
//  Created by Carlos on 15/03/26.
//

import SwiftUI
import Foundation

struct NewPromptView: View {
    var prompt: Prompt?
    var onClose: () -> Void
    
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var selectedFolder: String?
    @State private var isFavorite = false
    @State private var isSaving = false
    
    init(prompt: Prompt? = nil, onClose: @escaping () -> Void) {
        self.prompt = prompt
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Premium con Acciones
            HStack(alignment: .center) {
                Button(action: onClose) {
                    Text("Cancelar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(prompt != nil ? "Editar Prompt" : "Nuevo Prompt")
                        .font(.system(size: 15, weight: .bold))
                    Text(prompt != nil ? "Actualiza los detalles" : "Crea una herramienta")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: savePrompt) {
                    Text(prompt != nil ? "Guardar" : "Crear")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(title.isEmpty || content.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                .shadow(color: title.isEmpty || content.isEmpty ? .clear : Color.blue.opacity(0.2), radius: 4, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Contenido Principal - Optimizado para Espacio
            VStack(spacing: 20) {
                // Título y Editor integrados en una gran tarjeta "Content-First"
                VStack(spacing: 0) {
                    TextField("Título del prompt...", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    
                    Divider().padding(.horizontal, 20)
                    
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Escribe aquí el contenido de tu prompt...")
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .font(.system(size: 15))
                        }
                        
                        TextEditor(text: $content)
                            .font(.system(size: 15, design: .default))
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ocupar todo el espacio
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )
                
                // Organización compacta con ScrollView funcional (Carrusel)
                HStack(spacing: 12) {
                    // Favorito sutil con botón instantáneo
                    Button(action: { isFavorite.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundColor(isFavorite ? .yellow : .secondary)
                            Text("Prioridad")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isFavorite ? Color.yellow.opacity(0.1) : Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20)
                    
                    // Categorías horizontales: Carrusel con ScrollViewReader y Botones Físicos
                    ScrollViewReader { proxy in
                        HStack(spacing: 4) {
                            // Botón Scroll Izquierda
                            Button(action: { navigateCategory(forward: false, proxy: proxy) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    CategoryTag(title: "Sin categoría", icon: "folder", color: .gray, isSelected: selectedFolder == nil) {
                                        selectedFolder = nil
                                    }
                                    .id("none")
                                    
                                    ForEach(PredefinedCategory.allCases, id: \.self) { category in
                                        CategoryTag(title: category.displayName, icon: category.icon, color: category.color, isSelected: selectedFolder == category.displayName) {
                                            selectedFolder = category.displayName
                                        }
                                        .id(category.displayName)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 2)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .onChange(of: selectedFolder) { newSelection in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    proxy.scrollTo(newSelection ?? "none", anchor: .center)
                                }
                            }
                            
                            // Botón Scroll Derecha
                            Button(action: { navigateCategory(forward: true, proxy: proxy) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)
                .frame(height: 44)
            }
            .padding(24)
        }
        .frame(width: 600, height: 500)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // Decoración sutil
                Circle()
                    .fill(Color.blue.opacity(0.02))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: -250, y: 200)
            }
        )
        .onAppear {
            if let prompt = prompt {
                title = prompt.title
                content = prompt.content
                selectedFolder = prompt.folder
                isFavorite = prompt.isFavorite
            }
        }
    }
    
    private func savePrompt() {
        isSaving = true
        
        if let existingPrompt = prompt {
            var updated = existingPrompt
            updated.title = title
            updated.content = content
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.modifiedAt = Date()
            _ = promptService.updatePrompt(updated)
        } else {
            var new = Prompt(title: title, content: content, folder: selectedFolder)
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
        }
        
        onClose()
    }
    
    private func navigateCategory(forward: Bool, proxy: ScrollViewProxy? = nil) {
        let allCategories = [nil] + PredefinedCategory.allCases.map { $0.displayName }
        guard let currentIndex = allCategories.firstIndex(of: selectedFolder) else { return }
        
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % allCategories.count
        } else {
            nextIndex = (currentIndex - 1 + allCategories.count) % allCategories.count
        }
        
        let newSelection = allCategories[nextIndex]
        selectedFolder = newSelection
        
        if let proxy = proxy {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo(newSelection ?? "none", anchor: .center)
            }
        }
    }
}

struct CategoryTag: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    NewPromptView(onClose: {})
        .environmentObject(PromptService())
        .environmentObject(PreferencesManager.shared)
}
