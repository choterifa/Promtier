//
//  FloatingAIDraftView.swift
//  Promtier
//
//  VISTA: Editor rápido exclusivo para jugar y editar borradores con IA
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FloatingAIDraftView: View {
    @EnvironmentObject var manager: FloatingAIDraftManager
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var customCommand: String = ""
    // El estado ahora vive en el Manager para que se persista al cerrar
    @FocusState private var isDraftFocused: Bool
    @State private var localMonitor: Any?
    @State private var showSavedToast: Bool = false
    @State private var toastMsg: String = ""
    @State private var toastIcon: String = "checkmark.circle.fill"
    @State private var toastTimer: Timer?
    @State private var typewriterTimer: Timer?
    @State private var contentWordCountTask: Task<Void, Never>?
    @State private var lastToastShownAt: Date = .distantPast
    @State private var isTypewriterAnimating: Bool = false
    @State private var contentWordCount: Int = 0
    @State private var responseWordCount: Int = 0
    
    // Preset Editor State
    @State private var showPresetEditor: Bool = false
    @State private var isDraggingMagicImage = false
    @State private var newPresetTitle: String = ""
    @State private var newPresetInstruction: String = ""
    @State private var newPresetIcon: String = "sparkles"
    
    // Drag & Drop State
    @State private var isDraggingImage: Bool = false
    @State private var isMagicImageProcessing: Bool = false
    
    private var isAIAvailable: Bool {
        (preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty) ||
        (preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider().opacity(0.12)
            
            HStack(spacing: 0) {
                inputColumnView
                
                // ── DIVISOR SUTIL ───────────────────────────────────────────
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 40)
                
                outputColumnView
                
            }
            
            Divider().opacity(0.12)
            
            footerBar
        }
        .frame(width: 740, height: 570)
        .background(Color(NSColor.windowBackgroundColor))
        .promtierToast(
            isPresented: $showSavedToast,
            icon: toastIcon,
            message: toastMsg,
            iconColor: toastIcon == "sparkles" ? .purple : (toastIcon == "exclamationmark.triangle.fill" ? .orange : .green),
            autoHide: false
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 25, y: 12)
        .onAppear {
            isDraftFocused = true
            refreshWordCounts()
            checkAutoImprove()
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
            toastTimer?.invalidate()
            toastTimer = nil
            typewriterTimer?.invalidate()
            typewriterTimer = nil
            contentWordCountTask?.cancel()
            contentWordCountTask = nil
            isTypewriterAnimating = false
        }
        .onChange(of: manager.content) { _, _ in
            scheduleContentWordCountRefresh()
        }
        .onChange(of: manager.responseText) { _, _ in
            if !isTypewriterAnimating {
                responseWordCount = countWords(in: manager.responseText)
            }
        }
        .onChange(of: manager.isVisible) { _, visible in
            if visible {
                isDraftFocused = true
                refreshWordCounts()
                checkAutoImprove()
                setupKeyboardMonitor()
            } else {
                if let monitor = localMonitor {
                    NSEvent.removeMonitor(monitor)
                    localMonitor = nil
                }
                typewriterTimer?.invalidate()
                typewriterTimer = nil
                contentWordCountTask?.cancel()
                contentWordCountTask = nil
                isTypewriterAnimating = false
            }
        }
        .magicGlobalDropOverlay(isProcessing: isMagicImageProcessing) { data in
            generatePromptFromImage(data: data)
        }
    }

    private var inputColumnView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("PROMPT ORIGINAL")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                }
                .foregroundColor(.secondary.opacity(0.6))
                Spacer()
            }
            .frame(height: 28)
            .padding(.top, 20)
            .padding(.leading, 24).padding(.trailing, 16)

            ZStack(alignment: .topLeading) {
                if manager.content.isEmpty {
                    Text("Pega o escribe tu borrador aquí...")
                        .foregroundColor(.secondary.opacity(0.4))
                        .font(.system(size: 14 * preferences.fontSize.scale))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $manager.content)
                    .font(.system(size: 14 * preferences.fontSize.scale))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .disableNativeDrop()
                    .padding(12)
                    .focused($isDraftFocused)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
            .padding(.leading, 24).padding(.trailing, 16)
            .padding(.top, 10)

            HStack {
                HStack(spacing: 4) {
                    Text("\(manager.content.count) carácteres")
                    Text("•")
                    Text("\(contentWordCount) palabras")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(width: 370)
    }

    private var outputColumnView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 9, weight: .bold))
                    Text("RESULTADO IA")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                }
                .foregroundColor(.purple)

                if !manager.responseText.isEmpty && !manager.isGenerating {
                    HStack(spacing: 6) {
                        Button(action: {
                            saveResultAsPrompt()
                        }) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(PlainHoverButtonStyle(color: .blue, padding: (8, 6)))
                        .help("Guardar en galería")
                        .fixedSize()

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                manager.isDiffActive.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: manager.isDiffActive ? "doc.plaintext.fill" : "rectangle.2.swap")
                                Text(manager.isDiffActive ? "Texto" : "Diff")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(PlainHoverButtonStyle(color: .purple, active: manager.isDiffActive, padding: (8, 6)))
                        .help(manager.isDiffActive ? "Ver resultado final" : "Comparar cambios")
                        .fixedSize()

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                manager.content = manager.responseText
                                manager.responseText = ""
                            }
                            HapticService.shared.playLight()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right.circle.fill")
                                Text("Refill")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(PlainHoverButtonStyle(color: .blue, padding: (8, 6)))
                        .help("Mover resultado al editor original")
                        .fixedSize()
                    }
                }

                Spacer()
            }
            .frame(height: 28)
            .padding(.top, 20)
            .padding(.leading, 16).padding(.trailing, 24)

            ZStack(alignment: .topLeading) {
                if manager.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                        Text("IA trabajando...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = manager.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red.opacity(0.8))

                        VStack(spacing: 8) {
                            Text("Error de Conexión")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)

                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        Button(action: {
                            if let lastReq = manager.history.last?.input {
                                runAI(instruction: lastReq)
                            } else {
                                manager.error = nil
                            }
                        }) {
                            Text("Reintentar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.05)))
                } else if !manager.responseText.isEmpty {
                    if manager.isDiffActive {
                        ScrollView(showsIndicators: false) {
                            DiffTextView(oldText: manager.content, newText: manager.responseText)
                                .padding(12)
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.02)))
                    } else {
                        ScrollView(showsIndicators: false) {
                            Text(manager.responseText)
                                .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                .lineSpacing(5)
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.15))
                        Text("Los resultados de la IA\naparecerán aquí")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
            .padding(.leading, 16).padding(.trailing, 24)
            .padding(.top, 10)

            HStack {
                HStack(spacing: 4) {
                    Text("\(manager.responseText.count) carácteres")
                    Text("•")
                    Text("\(responseWordCount) palabras")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(width: 370)
        .background(Color.purple.opacity(0.015))
    }

    private func countWords(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func refreshWordCounts() {
        contentWordCount = countWords(in: manager.content)
        responseWordCount = countWords(in: manager.responseText)
    }

    private func scheduleContentWordCountRefresh() {
        let snapshot = manager.content
        contentWordCountTask?.cancel()
        contentWordCountTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            contentWordCount = countWords(in: snapshot)
        }
    }

    private func setupKeyboardMonitor() {
        if localMonitor != nil { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // ESC -> Close
            if event.keyCode == 53 {
                manager.hide()
                return nil
            }
            
            // Cmd + C -> Copy
            if modifiers == .command && event.keyCode == 8 {
                if isTextSelectedInDraft() { return event }
                let textToCopy = !manager.responseText.isEmpty ? manager.responseText : manager.content
                if !textToCopy.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)

                    showToast(
                        message: "¡Copiado!",
                        icon: "doc.on.clipboard.fill",
                        hideAfter: 1.5,
                        minInterval: 0.35
                    )
                    HapticService.shared.playSuccess()
                    return nil
                }
            }
            
            // Enter -> Run 'Mejorar' if focused on input (Shift+Enter for newline)
            if (event.keyCode == 36 || event.keyCode == 76) && isDraftFocused {
                if !modifiers.contains(.shift) {
                    if !manager.content.isEmpty && !manager.isGenerating {
                        runAI(instruction: "Optimiza este prompt para que sea más efectivo, añadiendo claridad técnica y mejores instrucciones.")
                        return nil
                    }
                } else {
                    // Shift + Enter -> Permitir nueva línea normal
                    return event
                }
            }
            
            // Cmd + Enter -> Reemplazar y Salir
            if modifiers == .command && (event.keyCode == 36 || event.keyCode == 76) {
                if !manager.responseText.isEmpty {
                    manager.content = manager.responseText
                    manager.hide()
                    return nil
                }
            }
            
            // Cmd + V -> Paste
            if modifiers == .command && event.keyCode == 9 {
                if !isDraftFocused {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        manager.content += str
                        return nil
                    }
                }
                return event
            }
            
            return event
        }
    }
    
    private func isTextSelectedInDraft() -> Bool {
        guard let window = NSApp.keyWindow,
              let fieldEditor = window.firstResponder as? NSTextView,
              fieldEditor.selectedRange().length > 0 else {
            return false
        }
        return true
    }
    
    private func checkAutoImprove() {
        if manager.shouldAutoImprove && !manager.content.isEmpty {
            // Un pequeño delay para que la transición de la ventana termine y se sienta natural
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                runAI(instruction: "Mejora la redacción y claridad de este prompt, manteniendo su intención original pero haciéndolo más efectivo para IAs.")
                manager.shouldAutoImprove = false
            }
        }
    }
    
    private func generatePromptFromImage(data: Data) {
        manager.content = ""
        runSingleAI(instruction: "Analiza la imagen adjunta y genera un prompt ultra-descriptivo para recrearla usando inteligencia artificial. Incluye detalles cinemáticos, sujetos centrales, paleta de colores dominante, estilo artístico y configuración de iluminación. Empieza directamente con el prompt en inglés o español sin frases introductorias.", content: "", imageData: data)
    }
    
    private func saveResultAsPrompt() {
        let contentToSave = manager.responseText.isEmpty ? manager.content : manager.responseText
        guard !contentToSave.isEmpty else { return }

        showToast(
            message: "Analizando y guardando...",
            icon: "sparkles",
            hideAfter: 0,
            minInterval: 0,
            force: true
        )
        
        Task {
            do {
                let metadata = try await AIServiceManager.shared.generatePromptMetadata(title: "", content: contentToSave)
                
                let newPrompt = Prompt(
                    title: metadata.title,
                    content: metadata.content,
                    promptDescription: metadata.description,
                    folder: nil, // Esto hará que la app intente auto-categorizarlo después si es posible, o se quede sin clasificar
                    icon: "sparkles",
                    negativePrompt: metadata.negativePrompt
                )
                
                await MainActor.run {
                    _ = PromptService.shared.createPrompt(newPrompt)

                    showToast(
                        message: "¡Guardado en Galería!",
                        icon: "square.and.arrow.down.fill",
                        hideAfter: 2.0,
                        minInterval: 0.2,
                        force: true
                    )
                    HapticService.shared.playSuccess()
                }
            } catch {
                // Fallback de guardado rápido si falla la IA
                await MainActor.run {
                    let newPrompt = Prompt(
                        title: "Quick Edit \(Date().formatted(.dateTime.day().month().hour().minute()))",
                        content: contentToSave,
                        folder: "Sin clasificar",
                        icon: "sparkles"
                    )
                    _ = PromptService.shared.createPrompt(newPrompt)

                    showToast(
                        message: "Guardado (Sin Metadata)",
                        icon: "exclamationmark.triangle.fill",
                        hideAfter: 2.0,
                        minInterval: 0.2,
                        force: true
                    )
                    HapticService.shared.playSuccess()
                }
            }
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Botón de Cerrar
            Button(action: { manager.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            // Título estilo Breadcrumb incorporado
            Text("Quick Draft")
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 4)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Historial de Sesión
                if !manager.history.isEmpty {
                    Menu {
                        ForEach(manager.history.reversed()) { item in
                            Button(action: {
                                withAnimation {
                                    manager.content = item.input
                                    manager.responseText = item.output
                                }
                            }) {
                                HStack {
                                    Text(item.input.prefix(30) + "...")
                                    Spacer()
                                    Text(item.timestamp, style: .time)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { manager.history.removeAll() }) {
                            Text("Limpiar Historial")
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Circle().fill(Color.primary.opacity(0.04)))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 32)
                    .help("Historial de la sesión")
                }
                
                // Botón de Copiar y Cerrar
                CopiarButton(isEnabled: !manager.content.isEmpty) {
                    let textToCopy = manager.responseText.isEmpty ? manager.content : manager.responseText
                    guard !textToCopy.isEmpty else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    HapticService.shared.playSuccess()
                    manager.hide()
                }
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
        .background(WindowDragView())
    }
    
    private var footerBar: some View {
        VStack(spacing: 0) {
            // Acciones rápidas (Horizontal Scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let defaultActions = [
                        ("Mejorar", "sparkles", "Optimiza este prompt para que sea más efectivo, añadiendo claridad técnica y mejores instrucciones."),
                        ("Traductor", "globe", "Traduce entre español e inglés de forma inteligente, manteniendo el contexto técnico de IA."),
                        ("Estructurar", "list.bullet.indent", "Añade estructura al prompt usando encabezados, listas de puntos y secciones claras (Markdown)."),
                        ("Conciso", "scissors", "Simplifica el prompt al máximo, eliminando redundancias pero manteniendo la esencia."),
                        ("Senior Dev", "eye.fill", "Actúa como un desarrollador senior y analiza este prompt buscando errores de lógica o mejores prácticas técnicas."),
                        ("Tabla", "tablecells.fill", "Transforma toda la información relevante de este prompt en una tabla formateada en Markdown.")
                    ]
                    
                    // Mostrar primero las por defecto
                    ForEach(defaultActions, id: \.0) { action in
                        QuickDraftActionButton(title: action.0, icon: action.1) {
                            runAI(instruction: action.2)
                        }
                        .disabled(!isAIAvailable || manager.isGenerating || manager.content.isEmpty)
                    }
                    
                    // Mostrar luego los presets personalizados
                    ForEach(preferences.draftPresets) { preset in
                        QuickDraftActionButton(title: preset.title, icon: preset.icon) {
                            runAI(instruction: preset.instruction)
                        }
                        .disabled(!isAIAvailable || manager.isGenerating || manager.content.isEmpty)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let index = preferences.draftPresets.firstIndex(where: { $0.id == preset.id }) {
                                    preferences.draftPresets.remove(at: index)
                                }
                            } label: {
                                Label("Eliminar Preset", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Botón para añadir preset (+)
                    Button(action: { 
                        newPresetTitle = ""
                        newPresetInstruction = ""
                        showPresetEditor = true 
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue.opacity(0.8))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .help("Crear nuevo preset personalizado")
                    .popover(isPresented: $showPresetEditor) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Nuevo Preset")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nombre Corto")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                TextField("Ej: Sarcástico, Pro...", text: $newPresetTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Instrucción para la IA")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                ZStack(alignment: .topLeading) {
                                    if newPresetInstruction.isEmpty {
                                        Text("Dile a la IA qué debe hacer (ej: 'Responde como un pirata'...)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary.opacity(0.4))
                                            .padding(.leading, 8) // Pixel-perfect calibration
                                            .padding(.top, 8)
                                            .allowsHitTesting(false)
                                    }
                                    
                                    TextEditor(text: $newPresetInstruction)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(height: 80)
                                        .padding(4) // Editor outer padding
                                        .scrollContentBackground(.hidden)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Icono")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                let icons = [
                                    "sparkles", "face.smiling", "bolt.fill", "star.fill", 
                                    "terminal.fill", "hammer.fill", "keyboard", "cpu",
                                    "doc.text.fill", "envelope.fill", "bubble.left.fill", "paperplane.fill",
                                    "pencil.circle.fill", "text.justify", "list.bullet", "link",
                                    "megaphone.fill", "heart.fill", "briefcase.fill", "globe"
                                ]
                                
                                ScrollView(.vertical, showsIndicators: false) {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                        ForEach(icons, id: \.self) { icon in
                                            Button(action: { newPresetIcon = icon }) {
                                                Image(systemName: icon)
                                                    .font(.system(size: 12))
                                                    .frame(width: 32, height: 32)
                                                    .background(newPresetIcon == icon ? Color.blue : Color.primary.opacity(0.05))
                                                    .foregroundColor(newPresetIcon == icon ? .white : .primary.opacity(0.8))
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(4)
                                }
                                .frame(height: 100)
                            }
                            
                            Button(action: {
                                if !newPresetTitle.isEmpty && !newPresetInstruction.isEmpty {
                                    let newPreset = DraftPreset(title: newPresetTitle, instruction: newPresetInstruction, icon: newPresetIcon)
                                    preferences.draftPresets.append(newPreset)
                                    showPresetEditor = false
                                    HapticService.shared.playSuccess()
                                }
                            }) {
                                Text("Guardar en la barra")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(newPresetTitle.isEmpty || newPresetInstruction.isEmpty ? Color.secondary.opacity(0.1) : Color.blue)
                                    .foregroundColor(newPresetTitle.isEmpty || newPresetInstruction.isEmpty ? .secondary : .white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(newPresetTitle.isEmpty || newPresetInstruction.isEmpty)
                        }
                        .padding(20)
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            
            Divider().opacity(0.1)
            
            // Custom Input
            HStack {
                MagicImageDropZone(isDraggingImage: $isDraggingImage) { data in
                    generatePromptFromImage(data: data)
                }
                
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    TextField("Escribe una instrucción para la IA...", text: $customCommand)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit {
                            if !customCommand.isEmpty { runAI(instruction: customCommand) }
                        }
                    
                    if !customCommand.isEmpty {
                        Button(action: { customCommand = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.primary.opacity(0.04)).overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)))
                
                SendDraftButton(isEnabled: isAIAvailable && !customCommand.isEmpty && !manager.content.isEmpty) {
                    runAI(instruction: customCommand)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.01))
            .overlay(Divider(), alignment: .top)
        }
    }
    
    private func runAI(instruction: String) {
        let content = manager.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, isAIAvailable else { return }
        
        runSingleAI(instruction: instruction, content: content)
    }
    
    private func runSingleAI(instruction: String, content: String, imageData: Data? = nil) {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        manager.responseText = ""
        responseWordCount = 0
        if imageData != nil { isMagicImageProcessing = true }
        customCommand = ""
        HapticService.shared.playImpact()
        manager.executeDraftTransformation(
            instruction: instruction,
            content: content,
            imageData: imageData,
            autoCopy: preferences.autoCopyDraft,
            onSuccess: { response in
                isMagicImageProcessing = false
                typewriterAnimation(response)
                manager.addToHistory(input: content, output: response)
                HapticService.shared.playSuccess()
            },
            onFailure: { _ in
                isMagicImageProcessing = false
            }
        )
    }
    
    private func typewriterAnimation(_ fullText: String) {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTypewriterAnimating = false

        manager.responseText = ""
        responseWordCount = 0

        let words = fullText.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let totalWords = words.count

        // Evita cientos de ticks para respuestas muy largas y mantiene UI fluida.
        if totalWords > 360 {
            manager.responseText = fullText
            responseWordCount = totalWords
            return
        }

        isTypewriterAnimating = true
        let wordsPerTick: Int

        if totalWords <= 40 {
            wordsPerTick = 1
        } else if totalWords <= 120 {
            wordsPerTick = 2
        } else if totalWords <= 240 {
            wordsPerTick = 4
        } else {
            wordsPerTick = 6
        }

        let tickInterval: TimeInterval = totalWords > 180 ? 0.012 : 0.015
        var index = 0

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { timer in
            if index < words.count {
                let nextIndex = min(index + wordsPerTick, words.count)
                let chunk = words[index..<nextIndex].joined(separator: " ")
                manager.responseText += (index == 0 ? "" : " ") + chunk
                index = nextIndex
                responseWordCount = index
            } else {
                timer.invalidate()
                typewriterTimer = nil
                isTypewriterAnimating = false
            }
        }
    }

    private func showToast(
        message: String,
        icon: String,
        hideAfter: TimeInterval,
        minInterval: TimeInterval,
        force: Bool = false
    ) {
        let now = Date()
        if !force && now.timeIntervalSince(lastToastShownAt) < minInterval {
            return
        }

        lastToastShownAt = now
        toastTimer?.invalidate()
        toastMsg = message
        toastIcon = icon

        withAnimation(.spring()) {
            showSavedToast = true
        }

        guard hideAfter > 0 else { return }

        toastTimer = Timer.scheduledTimer(withTimeInterval: hideAfter, repeats: false) { _ in
            withAnimation {
                showSavedToast = false
            }
        }
    }
}

struct CopiarButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 10))
                Text("Copiar")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.85) : Color.blue) : Color.gray.opacity(0.3))
                    .shadow(color: isEnabled && isHovered ? Color.blue.opacity(0.4) : (isEnabled ? Color.blue.opacity(0.2) : .clear), radius: isHovered ? 12 : 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SendDraftButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.9) : Color.blue) : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .offset(x: 1, y: -1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct QuickDraftActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.12) : Color.primary.opacity(0.06)) : Color.primary.opacity(0.03))
                    .overlay(
                        Capsule()
                            .stroke(isEnabled ? (isHovered ? Color.blue.opacity(0.4) : Color.primary.opacity(0.1)) : Color.primary.opacity(0.05), lineWidth: 1)
                    )
            )
            .foregroundColor(isEnabled ? (isHovered ? .blue : .primary) : .secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
