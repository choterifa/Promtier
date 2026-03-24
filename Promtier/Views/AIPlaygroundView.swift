//
//  AIPlaygroundView.swift
//  Promtier
//
//  VISTA: Panel para probar prompts con IA Local (Ollama)
//

import SwiftUI
import Combine

struct AIPlaygroundView: View {
    let prompt: String
    
    @EnvironmentObject var preferences: PreferencesManager
    
    @State private var cancellable: AnyCancellable?
    @State private var responseText: String = ""
    @State private var isGenerating: Bool = false
    @State private var error: String?
    @State private var improvementText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
                
                Spacer()
                
                let useOpenAI = !preferences.openAIApiKey.isEmpty
                let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
                
                if useOpenAI || useGemini {
                    HStack(spacing: 8) {
                        Text(useOpenAI ? "OpenAI" : "Google Gemini")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(useOpenAI ? .green : .blue)
                        
                        Button(action: generateResponse) {
                            if isGenerating {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("generate_test".localized(for: preferences.language))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isGenerating)
                    }
                } else {
                    Text("ai_service_not_configured".localized(for: preferences.language))
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            
            Divider()
            
            // Improvement Field
            HStack(spacing: 8) {
                TextField("ai_improvement_placeholder".localized(for: preferences.language), text: $improvementText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(8)
                
                if !improvementText.isEmpty {
                    Button(action: { improvementText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
            
            // Response Area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 13, design: .monospaced))
                    } else if responseText.isEmpty && !isGenerating {
                        Text("preview_placeholder".localized(for: preferences.language))
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.system(size: 13, design: .monospaced))
                    } else {
                        Text(responseText)
                            .font(.system(size: 13 * preferences.fontSize.scale, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.primary.opacity(0.01))
            
            if !responseText.isEmpty {
                Divider()
                HStack {
                    Spacer()
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(responseText, forType: .string)
                        HapticService.shared.playSuccess()
                    }) {
                        Label("copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(12)
                }
            }
        }
        .frame(minHeight: 200)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func generateResponse() {
        let useOpenAI = !preferences.openAIApiKey.isEmpty
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        
        guard useOpenAI || useGemini else { return }
        
        responseText = ""
        isGenerating = true
        error = nil
        HapticService.shared.playImpact()
        
        let finalPrompt = improvementText.isEmpty ? prompt : "\(prompt)\n\n[Instruction: \(improvementText)]"
        
        let publisher: AnyPublisher<String, Error>
        
        if useOpenAI {
            publisher = OpenAIService.shared.generate(prompt: finalPrompt, model: preferences.openAIDefaultModel, apiKey: preferences.openAIApiKey)
        } else {
            publisher = GeminiService.shared.generate(prompt: finalPrompt, model: preferences.geminiDefaultModel)
        }
        
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isGenerating = false
                if case .failure(let err) = completion {
                    self.error = err.localizedDescription
                }
            }, receiveValue: { chunk in
                responseText += chunk
            })
    }
}
