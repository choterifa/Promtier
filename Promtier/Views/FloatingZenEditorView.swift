//
//  FloatingZenEditorView.swift
//  Promtier
//
//  VISTA: Fast Add — mini editor flotante para crear prompts al toque
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Vision

struct FloatingZenEditorView: View {
    private enum ImageImportPolicy {
        static let maxInputBytes = 64 * 1024 * 1024
    }

    @EnvironmentObject var manager: FloatingZenManager
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var promptService: PromptService
    
    @FocusState private var focusedField: ZenField?
    @State private var showDiscardAlert = false
    @State private var isDraggingImage = false
    @State private var isDraggingMagicImage = false
    @State private var isMagicImageProcessing = false
    @State private var hoveredSlot: Int? = nil
    @State private var isHoveringPaste: Bool = false
    @State private var isHoveringOpen: Bool = false
    @State private var isHoveringClose: Bool = false
    @State private var isHoveringCollapse: Bool = false
    @State private var isHoveringMagic: Bool = false
    @State private var pulseMagic: Bool = false
    @State private var pulseMagicResetWorkItem: DispatchWorkItem?
    @State private var isCompressingImage: Bool = false
    @State private var isOCRing: Bool = false
    @State private var isGhostMode: Bool = false
    @State private var isMouseInside: Bool = true
    @State private var screenOCRLoading: Bool = false
    @State private var animatedPhase: CGFloat = 0
    @State private var hoverTitleOCR: Bool = false
    @State private var hoverContentOCR: Bool = false
    @State private var hoverEye: Bool = false
    @State private var hoverCloseBtn: Bool = false
    @State private var hoverSaveBtn: Bool = false
    @State private var folderColorByName: [String: Color] = [:]
    
    enum ZenField { case title, description, content }
    
    private var canSave: Bool {
        !manager.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isMagicAvailable: Bool {
        let prefs = PreferencesManager.shared
        return (!prefs.openAIApiKey.isEmpty && prefs.openAIEnabled) || (!prefs.geminiAPIKey.isEmpty && prefs.geminiEnabled)
    }
    
    private var categoryColor: Color? {
        guard let folderName = manager.selectedFolder else { return nil }
        return folderColorByName[folderName]
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            // ── ESTADO COMPLETO ───────────────────────────────────────────
            VStack(spacing: 0) {
                headerBar
                
                Divider().opacity(0.3)
                
                VStack(spacing: 0) {
                    // ── Title ──
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Escribe el título...", text: $manager.title, axis: .vertical)
                            .font(.system(size: 20, weight: .bold))
                            .textFieldStyle(.plain)
                            .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 80, alignment: .leading)
                            .focused($focusedField, equals: .title)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity((isGhostMode && !isMouseInside) ? 0.12 : 0.04))
                            )
                            .overlay(alignment: .trailing) {
                                Button(action: triggerScreenOCR) {
                                    Image(systemName: "text.viewfinder")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(hoverTitleOCR ? .blue : .blue.opacity(0.8))
                                        .padding(7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7)
                                                .fill(hoverTitleOCR ? Color.blue.opacity(0.15) : Color.blue.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                                .onHover { hoverTitleOCR = $0 }
                                .padding(.trailing, 10)
                                .animation(.easeInOut(duration: 0.2), value: hoverTitleOCR)
                            }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    
                    // ── Content ──
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CONTENIDO")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.secondary.opacity((isGhostMode && !isMouseInside) ? 0.85 : 0.5))
                                .tracking(1.5)
                            Spacer()
                            
                            MagicImageDropZone(isDraggingImage: $isDraggingMagicImage) { data in
                                extractMagicPrompt(from: data)
                            }
                            .scaleEffect(0.65)
                            .frame(width: 25, height: 25)
                        }
                        .padding(.top, 8)
                        
                        ZStack(alignment: .topLeading) {
                            if manager.content.isEmpty {
                                Text("Pega o escribe el contenido del prompt aquí...")
                                    .font(.system(size: 14 * preferences.fontSize.scale))
                                    .foregroundColor(.secondary.opacity((isGhostMode && !isMouseInside) ? 0.8 : 0.4))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $manager.content)
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .lineSpacing(4)
                                .focused($focusedField, equals: .content)
                                .scrollContentBackground(.hidden)
                                .scrollIndicators(.hidden)
                                .disableNativeDrop()
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if let scrollView = findNSScrollView(view: NSApp.keyWindow?.contentView) {
                                            scrollView.hasVerticalScroller = false
                                            scrollView.verticalScroller?.alphaValue = 0
                                            scrollView.drawsBackground = false
                                        }
                                    }
                                }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.primary.opacity((isGhostMode && !isMouseInside) ? 0.1 : 0.035))
                        )
                        .frame(minHeight: 200, maxHeight: .infinity)
                        .overlay(alignment: .bottomTrailing) {
                            Button(action: triggerScreenOCR) {
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(hoverContentOCR ? .blue : .blue.opacity(0.8))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(hoverContentOCR ? Color.blue.opacity(0.15) : Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                            .onHover { hoverContentOCR = $0 }
                            .padding(10)
                            .help("Extraer texto de pantalla")
                            .animation(.easeInOut(duration: 0.2), value: hoverContentOCR)
                        }
                    }
                    .padding(.horizontal, 22)
                    .layoutPriority(1)
                    
                    Spacer(minLength: 16)
                    
                    imageStrip
                }
                
                Divider().opacity(0.3)
                
                footerBar
            }
            .frame(minWidth: 440, maxWidth: .infinity, minHeight: 580, maxHeight: .infinity)
            .opacity((manager.isCollapsed) ? 0 : 1)
            .scaleEffect(manager.isCollapsed ? 0.9 : 1.0)
            .opacity(isGhostMode && !isMouseInside ? 0.6 : 1.0) // Dimming solo el contenido, no todo el window frame
            .allowsHitTesting(!manager.isCollapsed)
            
            // ── ESTADO "CUADRADITO" ─────────────────────────────────────────
            ZStack {
                WindowDragView { // Arrastre Y click combinados mediante lógica nativa de macOS
                    focusedField = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        manager.toggleCollapse()
                    }
                }
                
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.blue)
                }
                .allowsHitTesting(false) // Esto permite clickear la región visual pero pasar el evento al WindowDragView
            }
            .frame(width: 48, height: 48) // Todo el cuadradito más chico
            .opacity(manager.isCollapsed ? 1 : 0)
            .scaleEffect(manager.isCollapsed ? 1.0 : 0.5)
            .allowsHitTesting(manager.isCollapsed)
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    animatedPhase = -40
                }
            }
        }
        .frame(
            minWidth: manager.isCollapsed ? 48 : 440,
            maxWidth: manager.isCollapsed ? 48 : .infinity,
            minHeight: manager.isCollapsed ? 48 : 500,
            maxHeight: manager.isCollapsed ? 48 : .infinity
        )
        .animation(.easeInOut(duration: 0.3), value: isMouseInside)
        .onHover { isInside in
            isMouseInside = isInside
        }
        .background(
            ZStack {
                if isGhostMode && !isMouseInside {
                    ZenGlassView(material: .hudWindow, blendingMode: .behindWindow)
                        .overlay(Color(NSColor.windowBackgroundColor).opacity(0.2))
                        .opacity(0.9)
                } else {
                    Color(NSColor.windowBackgroundColor)
                    premiumBackground
                }
            }
        )
        .cornerRadius(manager.isCollapsed ? 24 : 16) // Más redondeado si es cuadradito de 48px
        .overlay(
            RoundedRectangle(cornerRadius: manager.isCollapsed ? 24 : 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .overlay {
            if manager.lastSaveSuccess {
                savedFeedbackOverlay
            }
        }
        .onAppear {
            focusedField = .title
            rebuildFolderColorMap(from: promptService.folders)
        }
        .onReceive(promptService.$folders) { folders in
            rebuildFolderColorMap(from: folders)
        }
        .onChange(of: manager.content) { oldValue, newValue in
            // Scroll logic simplified
            
            // Animación "Hey úsame" (pulseMagic) al pegar contenido en el prompt
            if newValue.count - oldValue.count >= 5, isMagicAvailable {
                pulseMagicResetWorkItem?.cancel()

                withAnimation(.easeInOut(duration: 0.2)) {
                    pulseMagic = true
                }

                let resetWorkItem = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulseMagic = false
                    }
                }
                pulseMagicResetWorkItem = resetWorkItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: resetWorkItem)
            }
        }
        .alert("¿Descartar cambios?", isPresented: $showDiscardAlert) {
            Button("Descartar", role: .destructive) {
                manager.resetAndHide()
            }
            Button("Continuar editando", role: .cancel) { }
        } message: {
            Text("Si cierras ahora, se perderán todos los cambios que hayas hecho en este prompt.")
        }
        .magicGlobalDropOverlay(isProcessing: isMagicImageProcessing) { data in
            extractMagicPrompt(from: data)
        }
    }

    private func rebuildFolderColorMap(from folders: [Folder]) {
        folderColorByName = Dictionary(uniqueKeysWithValues: folders.compactMap { folder in
            guard let hex = folder.color else { return nil }
            return (folder.name, Color(hex: hex))
        })
    }
    
    // MARK: - Premium Background
    
    private var premiumBackground: some View {
        ZStack {
            if let catColor = categoryColor, !manager.isCollapsed {
                // Capa de degradado base
                LinearGradient(
                    gradient: Gradient(colors: [
                        catColor.opacity(0.12),
                        catColor.opacity(0.05),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .transition(.opacity)
                
                // Brillo dinámico estilo "Halo"
                if preferences.isHaloEffectEnabled {
                    Circle()
                        .fill(catColor.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: -150, y: -150)
                }
            }
            
            // Efecto Mágico (IA Trabajando)
            if manager.isClassifying {
                AngularGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.2), .blue.opacity(0.2), .purple.opacity(0.2)]),
                    center: .center
                )
                .blur(radius: 40)
                .symbolEffect(.variableColor, isActive: true)
                .opacity(pulseMagic ? 0.8 : 0.4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseMagic)
                .onAppear { pulseMagic = true }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: manager.selectedFolder)
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        ZStack {
            // Capa del Título (Perfectamente centrada)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Fast Add")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.5)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
            
            // Capa de Botones
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
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
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
        }
        .frame(height: 50)
        .padding(.horizontal, 16)
        .background(WindowDragView())
    }
    
    @ViewBuilder
    private func placeholderView(index: Int) -> some View {
        Button(action: pasteImageFromClipboard) {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("Añadir")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 4], dashPhase: animatedPhase)
                    )
                    .foregroundColor(.blue.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var imageStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RESULTADOS VISUALES")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary.opacity((isGhostMode && !isMouseInside) ? 0.85 : 0.5))
                    .tracking(1.5)
                Spacer()
                if manager.showcaseImages.count < 3 {
                    Button(action: pasteImageFromClipboard) {
                        Label("Pegar ⌘V", systemImage: "doc.on.clipboard")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isHoveringPaste ? .blue : .blue.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(isHoveringPaste ? 0.12 : 0.05))
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
        .padding(.bottom, 12)
        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: $isDraggingImage) { providers in
            handleDrop(providers: providers)
        }
    }
    
    @ViewBuilder
    private func imageThumb(data: Data, index: Int) -> some View {
        FloatingZenImageThumb(data: data, index: index, manager: manager, mainEditor: self, animatedPhase: animatedPhase)
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
            .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.2, dash: [5, 5], dashPhase: isHovered ? animatedPhase : 0)
                            )
                            .foregroundColor(isHovered ? .blue.opacity(0.5) : .blue.opacity(0.15))
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
            // Botón de Magia
            Button(action: {
                if isMagicAvailable && !manager.isClassifying {
                    manager.performMagic()
                }
            }) {
                HStack(spacing: 6) {
                    if isMagicAvailable {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .symbolEffect(.variableColor, isActive: manager.isClassifying)
                        Text(isCompressingImage ? "Comprimiendo..." : (manager.isClassifying ? "IA..." : "Autocompletar"))
                            .font(.system(size: 10, weight: .bold))
                    } else {
                        Image(systemName: "sparkles.separator")
                            .font(.system(size: 14))
                            .opacity(0.5)
                        Text("Magic Off")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundColor(isMagicAvailable ? .accentColor : .secondary.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isMagicAvailable ? 
                        ((pulseMagic || isHoveringMagic) ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1)) 
                    : Color.primary.opacity(0.04)
                )
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.2), value: pulseMagic)
                .animation(.easeInOut(duration: 0.2), value: isHoveringMagic)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringMagic = $0 }
            .animation(.easeInOut(duration: 0.2), value: isHoveringMagic)
            .help(isMagicAvailable ? "Autocompletar lo faltante" : "No hay IA configurada")
            
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
            .foregroundColor(hoverCloseBtn ? .accentColor : .secondary)
            .onHover { hoverCloseBtn = $0 }
            .keyboardShortcut(.escape, modifiers: [])
            
            Button(action: { manager.saveAsNewPrompt() }) {
                HStack(spacing: 8) {
                    if manager.isSaving || manager.isClassifying {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.6)
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
                        .fill(canSave ? (hoverSaveBtn ? Color.accentColor.opacity(0.8) : Color.accentColor) : Color.gray.opacity(0.3))
                )
            }
            .buttonStyle(.plain)
            .onHover { hoverSaveBtn = $0 }
            .disabled(!canSave || manager.isSaving || manager.isClassifying)
            .keyboardShortcut(.return, modifiers: [.command])
            .background(
                Button("") { manager.saveAsNewPrompt() }
                    .keyboardShortcut("s", modifiers: [.command])
                    .opacity(0)
            )
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
        guard let image = NSImage(pasteboard: pb) else { return }
        isCompressingImage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let optimized = self.optimizeImage(image)
            DispatchQueue.main.async {
                self.isCompressingImage = false
                if let optimized { manager.showcaseImages.append(optimized) }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard manager.showcaseImages.count < 3 else { return false }
        isCompressingImage = true
        let remaining = 3 - manager.showcaseImages.count
        var pending = 0
        for provider in providers.prefix(remaining) {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                pending += 1
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    let optimized: Data? = {
                        guard let data, data.count <= ImageImportPolicy.maxInputBytes, let image = NSImage(data: data) else { return nil }
                        return self.optimizeImage(image)
                    }()
                    DispatchQueue.main.async {
                        pending -= 1
                        if let optimized { self.manager.showcaseImages.append(optimized) }
                        if pending <= 0 { self.isCompressingImage = false }
                    }
                }
            }
        }
        if pending == 0 { isCompressingImage = false }
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
    
    // MARK: - Screen OCR (TextSniper Style)
    
    private func triggerScreenOCR() {
        screenOCRLoading = true
        HapticService.shared.playImpact()
        
        // Ocultar ventana para no capturarse a sí misma
        // No podemos usar orderOut porque el script de screencapture es interactivo y bloquea
        // Así que usamos la opacidad para que sea "invisible"
        self.manager.hide() // Mejor ocultar de verdad
        
        DispatchQueue.global(qos: .userInitiated).async {
            let tempPath = "/tmp/promtier_ocr_capture.png"
            
            // Limpiar si existía
            try? FileManager.default.removeItem(atPath: tempPath)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", tempPath] // -i (interactivo), -x (sin sonido)
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Mostrar ventana de nuevo
                DispatchQueue.main.async {
                    self.manager.bringToFront()
                    
                    if FileManager.default.fileExists(atPath: tempPath) {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) {
                            self.performOCR(imageData: data)
                        }
                        // Limpiar
                        try? FileManager.default.removeItem(atPath: tempPath)
                    }
                    self.screenOCRLoading = false
                }
            } catch {
                print("Error triggering screencapture: \(error)")
                DispatchQueue.main.async {
                    self.manager.bringToFront()
                    self.screenOCRLoading = false
                }
            }
        }
    }

    func performOCR(imageData: Data) {
        let requestHandler = VNImageRequestHandler(data: imageData, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let extractedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HapticService.shared.playSuccess()
                    withAnimation(.spring()) {
                        if manager.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            manager.content = extractedText
                        } else {
                            manager.content += "\n\n" + extractedText
                        }
                    }
                } else {
                    HapticService.shared.playError()
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Vision OCR Error: \(error)")
            }
        }
    }
    
    private func extractMagicPrompt(from data: Data) {
        guard isMagicAvailable else { manager.title = "IA no configurada"; return }
        manager.content = ""
        isMagicImageProcessing = true
        
        Task {
            do {
                let instruction = "Analiza la imagen adjunta y genera un título corto (máximo 4 palabras) y un prompt ultra-descriptivo para recrearla usando inteligencia artificial. Incluye detalles cinemáticos, sujetos centrales, paleta de colores y estilo artístico. Devuelve el resultado EXACTAMENTE en este formato:\nTITULO: [título aquí]\nPROMPT: [prompt completo aquí]"
                let systemPrompt = """
                You are an elite AI Art Director and Vision Assistant. Your task is to act exclusively on the provided image.
                
                # INSTRUCTION FOR YOU:
                \(instruction)
                
                # IMPORTANT:
                Respond ONLY with the format requested. Do not add quotes, markdown formatting, or introductory text.
                """
                
                let response = try await AIServiceManager.shared.generate(prompt: systemPrompt, imageData: data)
                
                await MainActor.run {
                    self.isMagicImageProcessing = false
                    
                    let rawResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    let components = rawResponse.components(separatedBy: "PROMPT:")
                    
                    if components.count == 2 {
                        let rawTitle = components[0].replacingOccurrences(of: "TITULO:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        manager.content = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if manager.title.isEmpty || manager.title == "Generando prompt..." || manager.title == "Prompt de Imagen" {
                            manager.title = rawTitle.isEmpty ? "Prompt de Imagen" : rawTitle
                        }
                    } else {
                        manager.content = rawResponse
                        if manager.title.isEmpty || manager.title == "Generando prompt..." {
                            manager.title = "Prompt de Imagen"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isMagicImageProcessing = false
                    manager.content = "Error generando prompt: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct FloatingZenImageThumb: View {
    let data: Data
    let index: Int
    @ObservedObject var manager: FloatingZenManager
    let mainEditor: FloatingZenEditorView
    @State private var isFillMode = true
    @State private var isHovering = false
    let animatedPhase: CGFloat

    private var cachedImage: NSImage? {
        FastAddImageCache.shared.image(for: data)
    }

    var body: some View {
        if let nsImg = cachedImage {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                    .overlay(
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: isFillMode ? .fill : .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFillMode.toggle()
                            }
                        } label: {
                            Image(systemName: isFillMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(isHovering ? 1.0 : 0.0)
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
                
                Button(action: { manager.showcaseImages.remove(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)

                // Botón OCR
                Button {
                    mainEditor.performOCR(imageData: data)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 22, height: 22)
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: 4)
                .opacity(isHovering ? 1.0 : 0.0)
                .help("Extraer texto (OCR)")
                .alignmentGuide(.bottom) { _ in 0 }
            }
        }
    }
}

private final class FastAddImageCache {
    static let shared = FastAddImageCache()

    private let cache = NSCache<NSData, NSImage>()

    private init() {
        cache.countLimit = 48
    }

    func image(for data: Data) -> NSImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct ZenGlassView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}


// MARK: - Helper para arrastrar la ventana mediante clicks o tap
struct WindowDragView: NSViewRepresentable {
    var onTap: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> DraggableNSView {
        let view = DraggableNSView()
        view.onTap = onTap
        return view
    }
    
    func updateNSView(_ nsView: DraggableNSView, context: Context) {
        nsView.onTap = onTap
    }
}

class DraggableNSView: NSView {
    var onTap: (() -> Void)?
    private var didDrag = false
    private var mouseDownPoint: NSPoint = .zero
    private var mouseDownEvent: NSEvent?
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        didDrag = false
        mouseDownPoint = event.locationInWindow
        mouseDownEvent = event
    }
    
    override func mouseDragged(with event: NSEvent) {
        let current = event.locationInWindow
        let dx = abs(current.x - mouseDownPoint.x)
        let dy = abs(current.y - mouseDownPoint.y)
        
        // Evitar que el temblor natural de la mano inicie un drag (margen 3px)
        if (dx > 3 || dy > 3) && !didDrag {
            didDrag = true
            if let downEvent = mouseDownEvent {
                self.window?.performDrag(with: downEvent)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        // Si nunca se cruzó el umbral de arrastre, llamamos la acción de click!
        if !didDrag {
            onTap?()
        }
    }
}

// MARK: - Native Helpers
func findNSScrollView(view: NSView?) -> NSScrollView? {
    if let scrollView = view as? NSScrollView {
        return scrollView
    }
    for subview in view?.subviews ?? [] {
        if let found = findNSScrollView(view: subview) {
            return found
        }
    }
    return nil
}
