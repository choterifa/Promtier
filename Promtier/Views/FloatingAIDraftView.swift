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
    
    private var isAIAvailable: Bool {
        (preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty) ||
        (preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider().opacity(0.12)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Content Area ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("CONTENIDO")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.secondary.opacity(0.5))
                                .tracking(1.5)
                            Spacer()
                        }
                        .padding(.top, 16)
                        
                        ZStack(alignment: .topLeading) {
                            if manager.content.isEmpty {
                                Text("Pega o escribe tu borrador de prompt aquí...")
                                    .foregroundColor(.secondary.opacity(0.4))
                                    .font(.system(size: 14 * preferences.fontSize.scale))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $manager.content)
                                .font(.system(size: 14 * preferences.fontSize.scale))
                                .lineSpacing(4)
                                .scrollContentBackground(.hidden)
                                .focused($isDraftFocused)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.045)))
                        .frame(height: responseText.isEmpty && !isGenerating ? 320 : 160)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: responseText.isEmpty)
                    }
                    .padding(.horizontal, 22)
                    
                    if !responseText.isEmpty || isGenerating || error != nil {
                        // AI Result Area integrated like a section
                        VStack(alignment: .leading, spacing: 12) {
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
                                            Image(systemName: "arrow.up.doc.fill")
                                            Text("Reemplazar")
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.blue.opacity(0.8))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color.blue.opacity(0.08)))
                                }
                            }
                            .padding(.top, 12)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                if isGenerating {
                                    HStack(spacing: 12) {
                                        ProgressView().controlSize(.small)
                                        Text("IA pensando...")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 14)
                                } else if let error = error {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.system(size: 13, design: .monospaced))
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
                                } else {
                                    Text(responseText)
                                        .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                                        .lineSpacing(4)
                                        .textSelection(.enabled)
                                        .padding(14)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.03)))
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            Divider().opacity(0.12)
            
            // Footer with Close/Save style
            footerBar
        }
        .frame(width: 440, height: 500)
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
        }
        .onChange(of: manager.isVisible) { visible in
            if visible {
                isDraftFocused = true
                checkAutoImprove()
            }
        }
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
        HStack(spacing: 0) {
            // Botón de Cerrar
            Button(action: { manager.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Título centrado pill
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.purple)
                Text("AI Quick Draft")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
            .offset(x: 20)
            
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
