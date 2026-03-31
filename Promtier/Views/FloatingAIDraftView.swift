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
    @FocusState private var isDraftFocused: Bool
    @State private var localMonitor: Any?
    
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
                        Text("PROMPT ORIGINAL")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary.opacity(0.6))
                            .tracking(1.5)
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    
                    ZStack(alignment: .topLeading) {
                        if manager.content.isEmpty {
                            Text("Pega o escribe tu borrador aquí...")
                                .foregroundColor(.secondary.opacity(0.4))
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $manager.content)
                            .font(.system(size: 14 * preferences.fontSize.scale))
                            .lineSpacing(5)
                            .scrollContentBackground(.hidden)
                            .focused($isDraftFocused)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.04)))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: (responseText.isEmpty && !isGenerating && error == nil) ? .infinity : 370)
                
                // ── DIVISOR SUTIL ───────────────────────────────────────────
                if !responseText.isEmpty || isGenerating || error != nil {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 40)
                        .transition(.opacity)
                }
                
                // ── COLUMNA DERECHA: RESULTADO IA ──────────────────────────────
                if !responseText.isEmpty || isGenerating || error != nil {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                Text("RESULTADO IA")
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1.2)
                            }
                            .foregroundColor(.purple)
                            
                            Spacer()
                            
                            if !isGenerating {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        manager.content = responseText
                                        responseText = ""
                                    }
                                    HapticService.shared.playLight()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                                        Text("Reemplazar")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                if isGenerating {
                                    HStack(spacing: 12) {
                                        ProgressView().controlSize(.small)
                                        Text("IA trabajando...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 40)
                                } else if let error = error {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.system(size: 13, design: .monospaced))
                                        .padding(16)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.08)))
                                } else {
                                    Text(responseText)
                                        .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                        .lineSpacing(5)
                                        .textSelection(.enabled)
                                        .padding(18)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color.purple.opacity(0.03))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .stroke(Color.purple.opacity(0.08), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(width: 370)
                    .background(Color.purple.opacity(0.015))
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: responseText.isEmpty)
            
            Divider().opacity(0.12)
            
            footerBar
        }
        .frame(width: 740, height: 540)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.6)
                
                if preferences.isHaloEffectEnabled {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.06), Color(NSColor.windowBackgroundColor).opacity(0)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                WindowDragView()
            }
        )
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
                if isTextSelectedInDraft() {
                    return event
                }
                let textToCopy = responseText.isEmpty ? manager.content : responseText
                if !textToCopy.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    HapticService.shared.playSuccess()
                    return nil
                }
            }
            
            // Cmd + Enter (36 es Return) -> Copiar y Salir
            if modifiers == .command && (event.keyCode == 36 || event.keyCode == 76) {
                let textToCopy = responseText.isEmpty ? manager.content : responseText
                if !textToCopy.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    HapticService.shared.playSuccess()
                    manager.hide()
                    return nil
                }
            }
            
            // Cmd + V -> Paste (para asegurar que funcione en el panel)
            if modifiers == .command && event.keyCode == 9 {
                if let str = NSPasteboard.general.string(forType: .string) {
                    // Si el foco no está en el editor, pegamos al final
                    if !isDraftFocused {
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
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                Text("AI Quick Draft")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.primary.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.04))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1))
            )

            Spacer()
            
            // Botón de Copiar y Cerrar
            Button(action: {
                let textToCopy = responseText.isEmpty ? manager.content : responseText
                guard !textToCopy.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                HapticService.shared.playSuccess()
                manager.hide()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10))
                    Text("Copiar & Salir")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(manager.content.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .shadow(color: manager.content.isEmpty ? .clear : Color.blue.opacity(0.3), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(manager.content.isEmpty)
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
                    let actions: [(String, String, String)] = [
                        ("Traductor", "globe", "Traduce este prompt perfectamente al inglés si está en español, o al español si está en inglés, usando terminología adecuada de IA."),
                        ("Mejorar", "sparkles", "Mejora la redacción y claridad de este prompt, manteniendo su intención original pero haciéndolo más efectivo para IAs."),
                        ("A Inglés", "character.book.closed", "Traduce este prompt perfectamente al inglés, usando terminología adecuada de IA."),
                        ("A Español", "textformat", "Traduce este prompt perfectamente al español, manteniendo un tono claro y profesional."),
                        ("Profesional", "briefcase", "Reescribe este prompt para que suene mucho más profesional y corporativo."),
                        ("Conciso", "scissors", "Haz este prompt más corto y directo, eliminando palabras innecesarias pero manteniendo las instrucciones clave.")
                    ]
                    
                    ForEach(actions, id: \.0) { action in
                        Button(action: { runAI(instruction: action.2) }) {
                            HStack(spacing: 6) {
                                Image(systemName: action.1).font(.system(size: 10))
                                Text(action.0).font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!isAIAvailable || isGenerating || manager.content.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
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
                        Button(action: { customCommand = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Capsule().fill(Color.primary.opacity(0.04)).overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)))
                
                Button(action: { runAI(instruction: customCommand) }) {
                    ZStack {
                        Circle()
                            .fill((isAIAvailable && !customCommand.isEmpty && !manager.content.isEmpty) ? Color.blue : Color.secondary.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .offset(x: 1, y: -1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isAIAvailable || isGenerating || customCommand.isEmpty || manager.content.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.01))
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
                    self.responseText = response
                    self.isGenerating = false
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
}
