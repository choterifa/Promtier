//
//  FloatingZenEditorView.swift
//  Promtier
//
//  VISTA: Fast Add — mini editor flotante para crear prompts al toque
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FloatingZenEditorView: View {
    @EnvironmentObject var manager: FloatingZenManager
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    
    @FocusState private var focusedField: ZenField?
    @State private var showDiscardAlert = false
    @State private var isDraggingImage = false
    @State private var hoveredSlot: Int? = nil
    @State private var isHoveringPaste: Bool = false
    @State private var isHoveringOpen: Bool = false
    @State private var isHoveringClose: Bool = false
    @State private var isHoveringCollapse: Bool = false
    
    enum ZenField { case title, description, content }
    
    private var canSave: Bool {
        !manager.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isMagicAvailable: Bool {
        let prefs = PreferencesManager.shared
        return (!prefs.openAIApiKey.isEmpty && prefs.openAIEnabled) || (!prefs.geminiAPIKey.isEmpty && prefs.geminiEnabled)
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            // ── ESTADO COMPLETO ───────────────────────────────────────────
            VStack(spacing: 0) {
                headerBar
                
                Divider().opacity(0.3)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Title ──
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Escribe el título...", text: $manager.title, axis: .vertical)
                                .font(.system(size: 20, weight: .bold))
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .title)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035)))
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        
                        // ── Description ──
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Subtítulo o descripción corta...", text: $manager.promptDescription, axis: .vertical)
                                .font(.system(size: 13))
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .description)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                        
                        Divider().padding(.horizontal, 22)
                        
                        // ── Content ──
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("CONTENIDO")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .tracking(1.5)
                                Spacer()
                            }
                            .padding(.top, 20)
                            
                            ZStack(alignment: .topLeading) {
                                if manager.content.isEmpty {
                                    Text("Pega o escribe el contenido del prompt aquí...")
                                        .font(.system(size: 14 * preferences.fontSize.scale))
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                                
                                TextEditor(text: $manager.content)
                                    .font(.system(size: 14 * preferences.fontSize.scale))
                                    .lineSpacing(4)
                                    .focused($focusedField, equals: .content)
                                    .scrollContentBackground(.hidden)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.035)))
                            .frame(height: 260)
                        }
                        .padding(.horizontal, 22)
                        
                        Spacer(minLength: 20)
                        
                        imageStrip
                    }
                }
                
                Divider().opacity(0.3)
                
                footerBar
            }
            .frame(width: 440, height: 500)
            .opacity(manager.isCollapsed ? 0 : 1)
            .scaleEffect(manager.isCollapsed ? 0.9 : 1.0)
            .allowsHitTesting(!manager.isCollapsed)
            
            // ── ESTADO "CUADRADITO" ─────────────────────────────────────────
            ZStack {
                WindowDragView() // Para permitir arrastrarlo desde cualquier parte libre
                
                Button(action: {
                    focusedField = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        manager.toggleCollapse()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60, height: 60)
            .opacity(manager.isCollapsed ? 1 : 0)
            .scaleEffect(manager.isCollapsed ? 1.0 : 0.5)
            .allowsHitTesting(manager.isCollapsed)
        }
        .frame(width: manager.isCollapsed ? 60 : 440, height: manager.isCollapsed ? 60 : 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(manager.isCollapsed ? 30 : 16) // Más redondeado si es cuadradito
        .overlay(
            RoundedRectangle(cornerRadius: manager.isCollapsed ? 30 : 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .overlay {
            if manager.lastSaveSuccess {
                savedFeedbackOverlay
            }
        }
        .onAppear {
            focusedField = .title
        }
        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: $isDraggingImage) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: manager.content) { _, _ in
            // Scroll logic simplified
        }
        .alert("¿Descartar cambios?", isPresented: $showDiscardAlert) {
            Button("Descartar", role: .destructive) {
                manager.resetAndHide()
            }
            Button("Continuar editando", role: .cancel) { }
        } message: {
            Text("Si cierras ahora, se perderán todos los cambios que hayas hecho en este prompt.")
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack(spacing: 0) {
            // Botón de Cerrar (sustituye al semáforo)
            Button(action: {
                if manager.hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    manager.resetAndHide()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHoveringClose ? .primary : .secondary)
                    .padding(6)
                    .background(Circle().fill(isHoveringClose ? Color.red.opacity(0.1) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Cerrar")
            .onHover { isHoveringClose = $0 }
            
            // Botón de Colapsar
            Button(action: {
                focusedField = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    manager.toggleCollapse()
                }
            }) {
                Image(systemName: manager.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHoveringCollapse ? .primary : .secondary)
                    .padding(6)
                    .background(Circle().fill(isHoveringCollapse ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(manager.isCollapsed ? "Expandir" : "Colapsar")
            .onHover { isHoveringCollapse = $0 }
            .padding(.leading, 8)
            
            Spacer()
            
            // Título centrado
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Fast Add")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.5)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
            
            Spacer()
            
            // Botón de Abrir
            Button(action: {
                manager.hide()
                MenuBarManager.shared.showPopover()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isHoveringOpen ? .primary : .secondary)
                    .padding(6)
                    .background(Circle().fill(isHoveringOpen ? Color.primary.opacity(0.1) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Abrir editor completo")
            .onHover { isHoveringOpen = $0 }
        }
        .frame(height: 50) // Más margen vertical como solicitado
        .padding(.horizontal, 16)
        .background(WindowDragView())
    }
    
    private var imageStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RESULTADOS VISUALES")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary.opacity(0.5))
                    .tracking(1.5)
                Spacer()
                if manager.showcaseImages.count < 3 {
                    Button(action: pasteImageFromClipboard) {
                        Label("Pegar ⌘V", systemImage: "doc.on.clipboard")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isHoveringPaste ? .blue : .blue.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isHoveringPaste ? Color.blue.opacity(0.08) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringPaste = $0 }
                }
            }
            
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    if index < manager.showcaseImages.count {
                        imageThumb(data: manager.showcaseImages[index], index: index)
                    } else {
                        addImageSlot(index: index)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12) // Reducido de 16
    }
    
    @ViewBuilder
    private func imageThumb(data: Data, index: Int) -> some View {
        if let nsImg = NSImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 80)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                
                Button(action: { manager.showcaseImages.remove(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
    }
    
    @ViewBuilder
    private func addImageSlot(index: Int) -> some View {
        let isHovered = hoveredSlot == index
        Button(action: pasteImageFromClipboard) {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 18))
                Text("Añadir")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(isHovered ? .blue : .secondary.opacity(0.4))
            .frame(width: 110, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(isHovered ? .blue.opacity(0.3) : .secondary.opacity(0.2))
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSlot = hovering ? index : nil
        }
    }
    
    private var footerBar: some View {
        HStack(spacing: 16) {
            // Indicador de Magia
            HStack(spacing: 6) {
                if isMagicAvailable {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .symbolEffect(.variableColor, isActive: manager.isClassifying)
                    Text(manager.isClassifying ? "Clasificando..." : "Magic Active")
                        .font(.system(size: 10, weight: .bold))
                } else {
                    Image(systemName: "sparkles.separator")
                        .font(.system(size: 14))
                        .opacity(0.5)
                    Text("Magic Off")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(isMagicAvailable ? .purple : .secondary.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isMagicAvailable ? Color.purple.opacity(0.08) : Color.primary.opacity(0.04))
            .cornerRadius(8)
            
            Spacer()
            
            Button("Cerrar") {
                if manager.hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    manager.resetAndHide()
                }
            }
            .font(.system(size: 13, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button(action: { manager.saveAsNewPrompt() }) {
                HStack(spacing: 8) {
                    if manager.isSaving || manager.isClassifying {
                        ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .black))
                    }
                    Text("Guardar")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(canSave ? Color.blue : Color.gray.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave || manager.isSaving || manager.isClassifying)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.01))
    }
    
    private var savedFeedbackOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .blur(radius: 5)
                .cornerRadius(16)
            
            VStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Circle().fill(Color.blue))
                
                Text("Prompt Guardado")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Actions (Keep existing logic)
    
    private func pasteImageFromClipboard() {
        guard manager.showcaseImages.count < 3 else { return }
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb), let optimized = optimizeImage(image) {
            manager.showcaseImages.append(optimized)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard manager.showcaseImages.count < 3 else { return false }
        for provider in providers.prefix(3 - manager.showcaseImages.count) {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data, let image = NSImage(data: data), let optimized = self.optimizeImage(image) {
                        DispatchQueue.main.async { self.manager.showcaseImages.append(optimized) }
                    }
                }
            }
        }
        return true
    }
    
    private func optimizeImage(_ image: NSImage) -> Data? {
        let maxDim: CGFloat = 1024
        let size = image.size
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        guard let tiffData = newImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}

// MARK: - Helper para arrastrar la ventana
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return DraggableNSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggableNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        self.window?.performDrag(with: event)
    }
}

