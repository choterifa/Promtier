//
//  FloatingAIDraftView.swift
//  Promtier
//
//  VISTA: Editor rápido exclusivo para jugar y editar borradores con IA
//

import SwiftUI
import AppKit

struct FloatingAIDraftView: View {
    @EnvironmentObject var manager: FloatingAIDraftManager
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var responseText: String = ""
    @State private var isGenerating: Bool = false
    @State private var error: String?
    @State private var customCommand: String = ""
    @State private var isDiffActive: Bool = false
    @FocusState private var isDraftFocused: Bool
    @State private var localMonitor: Any?
    @State private var showSavedToast: Bool = false
    @State private var toastMsg: String = ""
    @State private var toastIcon: String = "checkmark.circle.fill"
    @State private var toastTimer: Timer?
    
    private var isAIAvailable: Bool {
        (preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty) ||
        (preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider().opacity(0.12)
            
            HStack(spacing: 0) {
                // ── COLUMNA IZQUIERDA: INPUT ─────────────────────────────────
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
                    .frame(height: 28) // Fixed height for alignment
                    .padding(.top, 20)
                    .padding(.leading, 24).padding(.trailing, 10)
                    
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
                            .padding(12)
                            .focused($isDraftFocused)
                    }
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
                    .padding(.leading, 24).padding(.trailing, 10)
                    .padding(.top, 10)
                    
                    // Info Row (Input)
                    HStack {
                        HStack(spacing: 4) {
                            Text("\(manager.content.count) carácteres")
                            Text("•")
                            Text("\(manager.content.split(separator: " ").count) palabras")
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
                
                // ── DIVISOR SUTIL ───────────────────────────────────────────
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 40)
                
                // ── COLUMNA DERECHA: RESULTADO IA ──────────────────────────────
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
                        
                        if !responseText.isEmpty && !isGenerating {
                            HStack(spacing: 6) {
                                // Guardar como nuevo
                                Button(action: { 
                                    saveResultAsPrompt()
                                }) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(PlainHoverButtonStyle(color: .blue, padding: (8, 6)))
                                .help("Guardar en galería")
                                .fixedSize()
                                
                                // Comparar
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isDiffActive.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isDiffActive ? "doc.plaintext.fill" : "rectangle.2.swap")
                                        Text(isDiffActive ? "Texto" : "Diff")
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(PlainHoverButtonStyle(color: .purple, active: isDiffActive, padding: (8, 6)))
                                .help(isDiffActive ? "Ver resultado final" : "Comparar cambios")
                                .fixedSize()
                                
                                // Reemplazar original
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        manager.content = responseText
                                        responseText = ""
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
                    .frame(height: 28) // Fixed height for alignment
                    .padding(.top, 20)
                    .padding(.leading, 10).padding(.trailing, 24)
                    
                    ZStack(alignment: .topLeading) {
                        if isGenerating {
                            VStack(spacing: 12) {
                                ProgressView().controlSize(.small)
                                Text("IA trabajando...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = error {
                            ScrollView {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                            }
                        } else if !responseText.isEmpty {
                            if isDiffActive {
                                ScrollView(showsIndicators: false) {
                                    DiffTextView(oldText: manager.content, newText: responseText)
                                        .padding(12)
                                }
                                .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.02)))
                            } else {
                                ScrollView(showsIndicators: false) {
                                    Text(responseText)
                                        .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                        .lineSpacing(5)
                                        .textSelection(.enabled)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            // Estado vacío simétrico
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
                    .padding(.leading, 10).padding(.trailing, 24)
                    .padding(.top, 10)
                    
                    // Info Row (Output)
                    HStack {
                        HStack(spacing: 4) {
                            Text("\(responseText.count) carácteres")
                            Text("•")
                            Text("\(responseText.split(separator: " ").count) palabras")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                        
                        Spacer()
                        
                        // Icono del modelo usado
                        Text(preferences.preferredAIService == .openai ? "GPT-4o" : "Gemini Pro")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.05)))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .frame(width: 370)
                .background(Color.purple.opacity(0.015))
            }
            
            Divider().opacity(0.12)
            
            footerBar
        }
        .frame(width: 740, height: 570)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .overlay(Color.primary.opacity(0.02))
        )
        .overlay(notificationToast, alignment: .top)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 25, y: 12)
        .onAppear {
            isDraftFocused = true
            checkAutoImprove()
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
        .onChange(of: manager.isVisible) { _, visible in
            if visible {
                isDraftFocused = true
                checkAutoImprove()
                setupKeyboardMonitor()
            }
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
                let textToCopy = !responseText.isEmpty ? responseText : manager.content
                if !textToCopy.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    
                    self.toastMsg = "¡Copiado!"
                    self.toastIcon = "doc.on.clipboard.fill"
                    withAnimation(.spring()) { showSavedToast = true }
                    
                    toastTimer?.invalidate()
                    toastTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        withAnimation { showSavedToast = false }
                    }
                    HapticService.shared.playSuccess()
                    return nil
                }
            }
            
            // Enter -> Run 'Mejorar' if focused on input (Shift+Enter for newline)
            if (event.keyCode == 36 || event.keyCode == 76) && isDraftFocused {
                if !modifiers.contains(.shift) {
                    if !manager.content.isEmpty && !isGenerating {
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
                if !responseText.isEmpty {
                    manager.content = responseText
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
    
    private var notificationToast: some View {
        Group {
            if showSavedToast {
                HStack(spacing: 8) {
                    Image(systemName: toastIcon)
                        .foregroundColor(.green)
                    Text(toastMsg)
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .foregroundColor(.white)
                .padding(.top, 42)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private func saveResultAsPrompt() {
        let contentToSave = responseText.isEmpty ? manager.content : responseText
        guard !contentToSave.isEmpty else { return }
        
        let newPrompt = Prompt(
            title: "Quick Edit \(Date().formatted(.dateTime.day().month().hour().minute()))",
            content: contentToSave,
            folder: "Sin clasificar",
            icon: "sparkles"
        )
        
        _ = PromptService.shared.createPrompt(newPrompt)
        
        self.toastMsg = "¡Guardado en Galería!"
        self.toastIcon = "square.and.arrow.down.fill"
        withAnimation(.spring()) {
            showSavedToast = true
        }
        
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation {
                showSavedToast = false
            }
        }
        
        HapticService.shared.playSuccess()
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
                                    responseText = item.output
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
                    let textToCopy = responseText.isEmpty ? manager.content : responseText
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
                        ("Conciso", "scissors", "Simplifica el prompt al máximo, eliminando redundancias pero manteniendo la esencia.")
                    ]
                    
                    // Mostrar primero las por defecto
                    ForEach(defaultActions, id: \.0) { action in
                        QuickDraftActionButton(title: action.0, icon: action.1) {
                            runAI(instruction: action.2)
                        }
                        .disabled(!isAIAvailable || isGenerating || manager.content.isEmpty)
                    }
                    
                    // Mostrar luego los presets personalizados
                    ForEach(preferences.draftPresets) { preset in
                        QuickDraftActionButton(title: preset.title, icon: preset.icon) {
                            runAI(instruction: preset.instruction)
                        }
                        .disabled(!isAIAvailable || isGenerating || manager.content.isEmpty)
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
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            
            Divider().opacity(0.1)
            
            // Custom Input
            HStack {
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
                        Button(action: {
                            let newPreset = DraftPreset(title: "Mi Preset \(preferences.draftPresets.count + 1)", instruction: customCommand, icon: "sparkles")
                            preferences.draftPresets.append(newPreset)
                            HapticService.shared.playSuccess()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Guardar comando como preset")
                        
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
        
        responseText = ""
        isGenerating = true
        error = nil
        customCommand = ""
        HapticService.shared.playImpact()
        
        let systemPrompt = """
        You are an elite Prompt Engineer assistant. Your task is to apply a specific transformation to an existing AI prompt.
        
        # INSTRUCTION FOR YOU:
        \(instruction)
        
        # ORIGINAL PROMPT TO EDIT:
        \(content)
        
        # IMPORTANT:
        Respond ONLY with the final transformed prompt. Do not add quotes around it. Do not include introductory text like "Here is the improved prompt:". Just the raw result.
        """
        
        Task {
            do {
                let response: String
                let prefs = preferences
                let model = prefs.preferredAIService == .openai ? prefs.openAIDefaultModel : prefs.geminiDefaultModel
                let apiKey = prefs.preferredAIService == .openai ? prefs.openAIApiKey : prefs.geminiAPIKey
                
                if prefs.preferredAIService == .openai {
                    response = try await OpenAIService.shared.generate(prompt: systemPrompt, model: model, apiKey: apiKey)
                } else {
                    response = try await GeminiService.shared.generate(prompt: systemPrompt, model: model)
                }
                
                await MainActor.run {
                    self.isGenerating = false
                    // Typewriter Effect
                    typewriterAnimation(response)
                    
                    // HISTORIAL
                    manager.addToHistory(input: content, output: response)
                    
                    // AUTO-COPY
                    if preferences.autoCopyDraft {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(response, forType: .string)
                    }
                    
                    HapticService.shared.playSuccess()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func typewriterAnimation(_ fullText: String) {
        self.responseText = ""
        let words = fullText.split(separator: " ", omittingEmptySubsequences: false).map { String($0) }
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if index < words.count {
                let word = words[index]
                self.responseText += (index == 0 ? "" : " ") + word
                index += 1
            } else {
                timer.invalidate()
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
