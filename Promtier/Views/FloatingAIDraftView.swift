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
            // Header y Actions
            headerBar
            
            Divider().opacity(0.3)
            
            // Layout Principal (Entrada arriba, Salida abajo)
            VStack(spacing: 0) {
                // Entrada: TextEditor libre del borrador
                ZStack(alignment: .topLeading) {
                    if manager.content.isEmpty {
                        Text("Pega o escribe tu borrador de prompt aquí...")
                            .foregroundColor(.secondary.opacity(0.4))
                            .font(.system(size: 14))
                            .padding(.horizontal, 5).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $manager.content)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .focused($isDraftFocused)
                }
                .padding(12)
                .frame(maxHeight: responseText.isEmpty && !isGenerating ? .infinity : 180)
                
                if !responseText.isEmpty || isGenerating || error != nil {
                    Divider().opacity(0.3)
                    
                    // Salida IA
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("RESULTADO IA")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(.purple)
                                    .tracking(1.5)
                                Spacer()
                                
                                if !isGenerating {
                                    Button(action: {
                                        manager.content = responseText
                                        responseText = ""
                                        HapticService.shared.playLight()
                                    }) {
                                        Label("Reemplazar Original", systemImage: "arrow.up.doc")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.vertical, 10)
                            } else if let error = error {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13, design: .monospaced))
                            } else {
                                Text(responseText)
                                    .font(.system(size: 13, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.primary.opacity(0.03))
                    .frame(maxHeight: .infinity)
                }
            }
            
            Divider().opacity(0.3)
            
            // Footer (Opciones Chidas y Custom Command)
            footerBar
        }
        .frame(width: 500, height: 500)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                if preferences.isHaloEffectEnabled {
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.08), Color.blue.opacity(0.03)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Color(NSColor.windowBackgroundColor).opacity(0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                WindowDragView()
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
        .onAppear {
            isDraftFocused = true
        }
    }
    
    private var headerBar: some View {
        HStack {
            Button(action: { manager.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                Text("AI Quick Draft")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.5)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.04))
                .overlay(Capsule().stroke(Color.purple.opacity(0.15), lineWidth: 1))
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
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Copiar & Salir")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }
    
    private var footerBar: some View {
        VStack(spacing: 0) {
            // Hot actions ("Opciones Chidas")
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
                            HStack(spacing: 4) {
                                Image(systemName: action.1).font(.system(size: 10))
                                Text(action.0).font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAIAvailable || isGenerating || manager.content.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            Divider().opacity(0.2)
            
            // Custom Instruction
            HStack {
                TextField("Escribe una instrucción para la IA (ej. hazlo más amable)...", text: $customCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        if !customCommand.isEmpty { runAI(instruction: customCommand) }
                    }
                
                Button(action: { runAI(instruction: customCommand) }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor((isAIAvailable && !customCommand.isEmpty && !manager.content.isEmpty) ? .blue : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(!isAIAvailable || isGenerating || customCommand.isEmpty || manager.content.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
        }
    }
    
    private func runAI(instruction: String) {
        let content = manager.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, isAIAvailable else { return }
        
        responseText = ""
        isGenerating = true
        error = nil
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
