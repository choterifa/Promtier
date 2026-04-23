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
    @EnvironmentObject var promptService: PromptService
    
    @State private var customCommand: String = ""
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
                if !manager.isFullSize {
                    AIDraftInputColumn(isDraftFocused: $isDraftFocused, wordCount: contentWordCount)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 40)
                }
                
                AIDraftOutputColumn(
                    wordCount: responseWordCount,
                    onSave: { saveResultAsPrompt() },
                    onRefill: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            manager.content = manager.responseText
                            manager.responseText = ""
                        }
                        HapticService.shared.playLight()
                    },
                    onRetry: { instruction in runAI(instruction: instruction) }
                )
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
            cleanup()
        }
        .onChange(of: manager.content) { _, _ in scheduleContentWordCountRefresh() }
        .onChange(of: manager.responseText) { _, _ in
            if !isTypewriterAnimating { responseWordCount = countWords(in: manager.responseText) }
        }
        .onChange(of: manager.isVisible) { _, visible in
            if visible {
                isDraftFocused = true
                refreshWordCounts()
                checkAutoImprove()
                setupKeyboardMonitor()
            } else {
                cleanup()
            }
        }
        .magicGlobalDropOverlay(isProcessing: isMagicImageProcessing) { data in
            generatePromptFromImage(data: data)
        }
    }

    // MARK: - Logic & Actions

    private func cleanup() {
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
            
            if event.keyCode == 53 { // ESC
                manager.hide()
                return nil
            }
            
            if modifiers == .command && event.keyCode == 8 { // Cmd + C
                if isTextSelectedInDraft() { return event }
                let textToCopy = !manager.responseText.isEmpty ? manager.responseText : manager.content
                if !textToCopy.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    showToast(message: "¡Copiado!", icon: "doc.on.clipboard.fill", hideAfter: 1.5, minInterval: 0.35)
                    HapticService.shared.playSuccess()
                    return nil
                }
            }
            
            if (event.keyCode == 36 || event.keyCode == 76) && isDraftFocused { // Enter
                if !modifiers.contains(.shift) {
                    if !manager.content.isEmpty && !manager.isGenerating {
                        runAI(instruction: "Optimiza este prompt para que sea más efectivo, añadiendo claridad técnica y mejores instrucciones.")
                        return nil
                    }
                }
                return event
            }
            
            if modifiers == .command && (event.keyCode == 36 || event.keyCode == 76) { // Cmd + Enter
                if !manager.responseText.isEmpty {
                    manager.content = manager.responseText
                    manager.hide()
                    return nil
                }
            }
            
            return event
        }
    }
    
    private func isTextSelectedInDraft() -> Bool {
        guard let window = NSApp.keyWindow,
              let fieldEditor = window.firstResponder as? NSTextView,
              fieldEditor.selectedRange().length > 0 else { return false }
        return true
    }
    
    private func checkAutoImprove() {
        if manager.shouldAutoImprove && !manager.content.isEmpty {
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

        showToast(message: "Analizando y guardando...", icon: "sparkles", hideAfter: 0, minInterval: 0, force: true)
        
        Task {
            do {
                let metadata = try await AIServiceManager.shared.generatePromptMetadata(title: "", content: contentToSave)
                await MainActor.run {
                    let newPrompt = Prompt(title: metadata.title, content: metadata.content, promptDescription: metadata.description, folder: nil, icon: "sparkles", negativePrompt: metadata.negativePrompt)
                    _ = promptService.createPrompt(newPrompt)
                    showToast(message: "¡Guardado en Galería!", icon: "square.and.arrow.down.fill", hideAfter: 2.0, minInterval: 0.2, force: true)
                    HapticService.shared.playSuccess()
                }
            } catch {
                await MainActor.run {
                    let newPrompt = Prompt(title: "Quick Edit \(Date().formatted(.dateTime.day().month().hour().minute()))", content: contentToSave, folder: "Sin clasificar", icon: "sparkles")
                    _ = promptService.createPrompt(newPrompt)
                    showToast(message: "Guardado (Sin Metadata)", icon: "exclamationmark.triangle.fill", hideAfter: 2.0, minInterval: 0.2, force: true)
                    HapticService.shared.playSuccess()
                }
            }
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
                NotificationService.shared.sendAIDraftNotification(title: "ai_draft_ready_title".localized(for: preferences.language), body: "ai_draft_ready_body".localized(for: preferences.language))
            },
            onFailure: { _ in isMagicImageProcessing = false }
        )
    }
    
    private func typewriterAnimation(_ fullText: String) {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTypewriterAnimating = false
        manager.responseText = ""
        responseWordCount = 0

        let totalChars = fullText.count
        
        // Si es extremadamente largo, mostrar todo de golpe
        if totalChars > 2500 {
            manager.responseText = fullText
            responseWordCount = countWords(in: fullText)
            return
        }

        isTypewriterAnimating = true
        
        // Ajustar velocidad para que sea visible pero ágil
        let charsPerTick: Int
        if totalChars <= 300 { charsPerTick = 2 }
        else if totalChars <= 800 { charsPerTick = 5 }
        else if totalChars <= 1500 { charsPerTick = 12 }
        else { charsPerTick = 20 }
        
        var currentIndex = fullText.startIndex
        let startTime = Date()

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            // Forzar finalización si pasa de 1.2 segundos
            if Date().timeIntervalSince(startTime) > 1.2 {
                manager.responseText = fullText
                timer.invalidate()
                typewriterTimer = nil
                isTypewriterAnimating = false
                responseWordCount = countWords(in: fullText)
                return
            }

            if currentIndex < fullText.endIndex {
                let nextIndex = fullText.index(currentIndex, offsetBy: charsPerTick, limitedBy: fullText.endIndex) ?? fullText.endIndex
                let chunk = fullText[currentIndex..<nextIndex]
                manager.responseText += String(chunk)
                currentIndex = nextIndex
                
                if manager.responseText.count % 50 == 0 || currentIndex == fullText.endIndex {
                    responseWordCount = countWords(in: manager.responseText)
                }
            } else {
                timer.invalidate()
                typewriterTimer = nil
                isTypewriterAnimating = false
                responseWordCount = countWords(in: fullText)
            }
        }
    }

    private func showToast(message: String, icon: String, hideAfter: TimeInterval, minInterval: TimeInterval, force: Bool = false) {
        let now = Date()
        if !force && now.timeIntervalSince(lastToastShownAt) < minInterval { return }
        lastToastShownAt = now
        toastTimer?.invalidate()
        toastMsg = message
        toastIcon = icon
        withAnimation(.spring()) { showSavedToast = true }
        guard hideAfter > 0 else { return }
        toastTimer = Timer.scheduledTimer(withTimeInterval: hideAfter, repeats: false) { _ in
            withAnimation { showSavedToast = false }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: { manager.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            Text("Quick Draft")
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 4)
            
            Spacer()
            
            HStack(spacing: 8) {
                if !manager.history.isEmpty {
                    historyMenu
                }
                
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

    private var historyMenu: some View {
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
                        Text(item.timestamp, style: .time).foregroundColor(.secondary)
                    }
                }
            }
            Divider()
            Button(role: .destructive, action: { manager.history.removeAll() }) { Text("Limpiar Historial") }
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
    
    private var footerBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    defaultActionButtons
                    customPresetButtons
                    addPresetButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            
            Divider().opacity(0.1)
            
            HStack {
                MagicImageDropZone(isDraggingImage: $isDraggingImage) { data in generatePromptFromImage(data: data) }
                customCommandInput
                SendDraftButton(isEnabled: isAIAvailable && !customCommand.isEmpty && !manager.content.isEmpty) { runAI(instruction: customCommand) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.01))
            .overlay(Divider(), alignment: .top)
        }
    }

    private var defaultActionButtons: some View {
        let actions = [
            ("Mejorar", "sparkles", "Optimiza este prompt para que sea más efectivo, añadiendo claridad técnica y mejores instrucciones."),
            ("Traductor", "globe", "Traduce entre español e inglés de forma inteligente, manteniendo el contexto técnico de IA."),
            ("Estructurar", "list.bullet.indent", "Añade estructura al prompt usando encabezados, listas de puntos y secciones claras (Markdown)."),
            ("Conciso", "scissors", "Simplifica el prompt al máximo, eliminando redundancias pero manteniendo la esencia."),
            ("Senior Dev", "eye.fill", "Actúa como un desarrollador senior y analiza este prompt buscando errores de lógica o mejores prácticas técnicas."),
            ("Tabla", "tablecells.fill", "Transforma toda la información relevante de este prompt en una tabla formateada en Markdown.")
        ]
        
        return ForEach(actions, id: \.0) { action in
            QuickDraftActionButton(title: action.0, icon: action.1) { runAI(instruction: action.2) }
                .disabled(!isAIAvailable || manager.isGenerating || manager.content.isEmpty)
        }
    }

    private var customPresetButtons: some View {
        ForEach(preferences.draftPresets) { preset in
            QuickDraftActionButton(title: preset.title, icon: preset.icon) { runAI(instruction: preset.instruction) }
                .disabled(!isAIAvailable || manager.isGenerating || manager.content.isEmpty)
                .contextMenu {
                    Button(role: .destructive, action: {
                        if let index = preferences.draftPresets.firstIndex(where: { $0.id == preset.id }) { preferences.draftPresets.remove(at: index) }
                    }) { Label("Eliminar Preset", systemImage: "trash") }
                }
        }
    }

    private var addPresetButton: some View {
        Button(action: { newPresetTitle = ""; newPresetInstruction = ""; showPresetEditor = true }) {
            Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundColor(.blue.opacity(0.8)).padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .help("Crear nuevo preset personalizado")
        .popover(isPresented: $showPresetEditor) { presetEditorView }
    }

    private var presetEditorView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nuevo Preset").font(.system(size: 13, weight: .bold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre Corto").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                TextField("Ej: Sarcástico, Pro...", text: $newPresetTitle).textFieldStyle(.roundedBorder).font(.system(size: 12))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Instrucción para la IA").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                ZStack(alignment: .topLeading) {
                    if newPresetInstruction.isEmpty {
                        Text("Dile a la IA qué debe hacer...").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.4)).padding(.leading, 8).padding(.top, 8).allowsHitTesting(false)
                    }
                    TextEditor(text: $newPresetInstruction).font(.system(size: 11, design: .monospaced)).frame(height: 80).padding(4).scrollContentBackground(.hidden).background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04))).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }
            }
            
            iconPickerGrid
            
            savePresetButton
        }
        .padding(20).frame(width: 300)
    }

    private var iconPickerGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icono").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            let icons = ["sparkles", "face.smiling", "bolt.fill", "star.fill", "terminal.fill", "hammer.fill", "keyboard", "cpu", "doc.text.fill", "envelope.fill", "bubble.left.fill", "paperplane.fill", "pencil.circle.fill", "text.justify", "list.bullet", "link", "megaphone.fill", "heart.fill", "briefcase.fill", "globe"]
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: { newPresetIcon = icon }) {
                            Image(systemName: icon).font(.system(size: 12)).frame(width: 32, height: 32).background(newPresetIcon == icon ? Color.blue : Color.primary.opacity(0.05)).foregroundColor(newPresetIcon == icon ? .white : .primary.opacity(0.8)).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            .frame(height: 100)
        }
    }

    private var savePresetButton: some View {
        Button(action: {
            if !newPresetTitle.isEmpty && !newPresetInstruction.isEmpty {
                let newPreset = DraftPreset(title: newPresetTitle, instruction: newPresetInstruction, icon: newPresetIcon)
                preferences.draftPresets.append(newPreset)
                showPresetEditor = false
                HapticService.shared.playSuccess()
            }
        }) {
            Text("Guardar en la barra").font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 10).background(newPresetTitle.isEmpty || newPresetInstruction.isEmpty ? Color.secondary.opacity(0.1) : Color.blue).foregroundColor(newPresetTitle.isEmpty || newPresetInstruction.isEmpty ? .secondary : .white).cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(newPresetTitle.isEmpty || newPresetInstruction.isEmpty)
    }

    private var customCommandInput: some View {
        HStack {
            Image(systemName: "terminal").font(.system(size: 10)).foregroundColor(.secondary)
            TextField("Escribe una instrucción para la IA...", text: $customCommand).textFieldStyle(.plain).font(.system(size: 12)).onSubmit { if !customCommand.isEmpty { runAI(instruction: customCommand) } }
            if !customCommand.isEmpty {
                Button(action: { customCommand = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary.opacity(0.5)) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(Color.primary.opacity(0.04)).overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)))
    }
}
