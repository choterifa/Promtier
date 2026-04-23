import SwiftUI
struct AlternativeGeneratorView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Environment(\.dismiss) var dismiss
    let originalPrompt: String
    var onGenerate: (String) -> Void
    @State private var setting: String = ""
    @State private var clothing: String = ""
    @State private var lighting: String = ""
    @State private var mood: String = ""
    @State private var extraInstructions: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    let presetSettings = ["Cyberpunk city", "Enchanted forest", "Minimalist studio", "Space station"]
    let presetClothing = ["Techwear", "Elegant suit", "Casual streetwear", "Medieval armor"]
    let presetLighting = ["Cinematic", "Neon glow", "Soft morning light", "Harsh shadows"]
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generar Alternativa con IA")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Define los elementos que deseas cambiar. La IA adaptará el prompt original para reflejar estas variaciones.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    inputSection(title: "Escenario / Lugar", text: $setting, presets: presetSettings)
                    inputSection(title: "Ropa / Estilo", text: $clothing, presets: presetClothing)
                    inputSection(title: "Iluminación / Atmósfera", text: $lighting, presets: presetLighting)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Otra instrucción (opcional):")
                            .font(.system(size: 12, weight: .semibold))
                        TextField("Ej: Haz que parezca una pintura al óleo...", text: $extraInstructions)
                            .textFieldStyle(.roundedBorder)
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                .padding(16)
            }
            // Footer
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Text("Cancelar")
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                Button(action: generateAlternative) {
                    HStack {
                        if isGenerating {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text("Generar Alternativa")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
        }
        .frame(width: 450, height: 550)
    }
    private func inputSection(title: String, text: Binding<String>, presets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            TextField("Escribe o selecciona...", text: text)
                .textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button(action: { text.wrappedValue = preset }) {
                            Text(preset)
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(text.wrappedValue == preset ? Color.blue.opacity(0.2) : Color.primary.opacity(0.08)))
                                .foregroundColor(text.wrappedValue == preset ? .blue : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    private func generateAlternative() {
        guard !originalPrompt.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        let instructions = [
            setting.isEmpty ? "" : "Change the setting/place to: \(setting)",
            clothing.isEmpty ? "" : "Change the clothing/style to: \(clothing)",
            lighting.isEmpty ? "" : "Change the lighting/atmosphere to: \(lighting)",
            extraInstructions.isEmpty ? "" : "Additional changes: \(extraInstructions)"
        ].filter { !$0.isEmpty }.joined(separator: "\n")
        let systemPrompt = """
        You are an expert prompt engineer. The user wants to create an ALTERNATIVE variation of their existing prompt, keeping the core idea and variables {{...}} exactly the same, but adapting it based on these new parameters:
        PARAMETERS TO APPLY:
        \(instructions.isEmpty ? "Just make a high-quality alternative version of the prompt with a different creative angle." : instructions)
        ORIGINAL PROMPT:
        \(originalPrompt)
        INSTRUCTION:
        Respond ONLY with the newly generated alternative prompt. Do not add quotes, labels, or conversational filler.
        """
        Task {
            do {
                let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                await MainActor.run {
                    self.isGenerating = false
                    self.onGenerate(fullResponse.trimmingCharacters(in: .whitespacesAndNewlines))
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
