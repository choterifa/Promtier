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
    
    @FocusState private var focusedField: ZenField?
    @State private var isDraggingImage = false
    @State private var hoveredSlot: Int? = nil
    
    enum ZenField { case title, description, content }
    
    private var canSave: Bool {
        !manager.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── Header ────────────────────────────────────────────────
            headerBar
            
            Divider()
            
            // ── Title ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Label("TÍTULO", systemImage: "text.cursor")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue.opacity(0.7))
                    .tracking(1)
                
                TextField("Escribe el título del prompt...", text: $manager.title, axis: .vertical)
                    .font(.system(size: 16, weight: .bold))
                    .textFieldStyle(.plain)
                    .lineLimit(2)
                    .focused($focusedField, equals: .title)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            
            Divider().padding(.horizontal, 14)
            
            // ── Description ───────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Label("DESCRIPCIÓN", systemImage: "text.quote")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1)
                
                TextField("Resumen corto (opcional)...", text: $manager.promptDescription, axis: .vertical)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .textFieldStyle(.plain)
                    .lineLimit(2)
                    .focused($focusedField, equals: .description)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)
            
            Divider().padding(.horizontal, 14)
            
            // ── Content ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Label("CONTENIDO", systemImage: "doc.text")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                
                TextEditor(text: $manager.content)
                    .font(.system(size: 13 * preferences.fontSize.scale))
                    .focused($focusedField, equals: .content)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 110, maxHeight: 200)
            }
            
            Divider()

            // ── Image strip ───────────────────────────────────────────
            imageStrip
            
            Divider()
            
            // ── Footer ────────────────────────────────────────────────
            footerBar
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
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
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            Text("Fast Add")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                manager.hide()
                MenuBarManager.shared.showPopover()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Abrir editor completo")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }
    
    private var imageStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("IMÁGENES", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1)
                
                Spacer()
                
                // Paste from clipboard hint
                if manager.showcaseImages.count < 3 {
                    Button(action: pasteImageFromClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9, weight: .bold))
                            Text("Pegar ⌘V")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    if index < manager.showcaseImages.count {
                        imageThumb(data: manager.showcaseImages[index], index: index)
                    } else {
                        addImageSlot(index: index)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(isDraggingImage ? 0.06 : 0.0))
        .animation(.easeInOut(duration: 0.15), value: isDraggingImage)
    }
    
    @ViewBuilder
    private func imageThumb(data: Data, index: Int) -> some View {
        if let nsImg = NSImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 64)
                    .cornerRadius(8)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                
                Button(action: { manager.showcaseImages.remove(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }
        }
    }
    
    @ViewBuilder
    private func addImageSlot(index: Int) -> some View {
        let isHovered = hoveredSlot == index
        
        Button(action: pasteImageFromClipboard) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.blue.opacity(0.07) : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundColor(isHovered ? Color.blue.opacity(0.4) : Color.primary.opacity(0.15))
                    )
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                
                VStack(spacing: 5) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isHovered ? .blue.opacity(0.7) : .secondary.opacity(0.4))
                    Text("⌘V / arrastrar")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .frame(width: 88, height: 64)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredSlot = hovering ? index : nil
            }
        }
    }
    
    private var footerBar: some View {
        HStack(spacing: 12) {
            Text("\(manager.content.count) chars")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.4))
            
            Spacer()
            
            Button("Cancelar") {
                manager.resetAndHide()
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .keyboardShortcut(.escape, modifiers: [])
            
            Button(action: { manager.saveAsNewPrompt() }) {
                HStack(spacing: 6) {
                    if manager.isSaving {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                    }
                    Text("Guardar Prompt")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(canSave ? Color.blue : Color.gray.opacity(0.35))
                        .shadow(color: canSave ? Color.blue.opacity(0.25) : .clear, radius: 6, y: 3)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave || manager.isSaving)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }
    
    private var savedFeedbackOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .cornerRadius(12)
            
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
                Text("¡Guardado!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
    
    // MARK: - Actions
    
    /// Pega una imagen desde el portapapeles (⌘V). No requiere acceso a archivos.
    private func pasteImageFromClipboard() {
        guard manager.showcaseImages.count < 3 else { return }
        
        let pb = NSPasteboard.general
        
        // Intentar obtener imagen directa
        if let image = NSImage(pasteboard: pb),
           let optimized = optimizeImage(image) {
            manager.showcaseImages.append(optimized)
            return
        }
        
        // Fallback: leer datos de imagen del portapapeles
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png, NSPasteboard.PasteboardType("public.jpeg")]
        for type in imageTypes {
            if let data = pb.data(forType: type),
               let image = NSImage(data: data),
               let optimized = optimizeImage(image) {
                manager.showcaseImages.append(optimized)
                return
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard manager.showcaseImages.count < 3 else { return false }
        
        var handled = false
        for provider in providers.prefix(3 - manager.showcaseImages.count) {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    if let data = data, let image = NSImage(data: data),
                       let optimized = self.optimizeImage(image) {
                        DispatchQueue.main.async {
                            if self.manager.showcaseImages.count < 3 {
                                self.manager.showcaseImages.append(optimized)
                            }
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data,
                          let urlString = String(data: data, encoding: .utf8),
                          let url = URL(string: urlString),
                          let imgData = try? Data(contentsOf: url),
                          let image = NSImage(data: imgData),
                          let optimized = self.optimizeImage(image) else { return }
                    DispatchQueue.main.async {
                        if self.manager.showcaseImages.count < 3 {
                            self.manager.showcaseImages.append(optimized)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    
    private func optimizeImage(_ image: NSImage) -> Data? {
        let maxDim: CGFloat = 1024
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        
        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}
