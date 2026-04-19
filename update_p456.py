import re

path_vm = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/ViewModels/NewPromptViewModel.swift"
with open(path_vm, "r") as f:
    vm_content = f.read()

# Add generateAlternativeDirect
new_method_vm = """
    func generateAlternativeDirect(preferences: PreferencesManager) {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return }

        isGeneratingAlternativeDirect = true
        HapticService.shared.playImpact()

        let systemPrompt = \"\"\"
        Eres un ingeniero de prompts experto y creativo. Genera una versión ALTERNATIVA o variada del siguiente prompt.
        MANTÉN EL MISMO IDIOMA EXACTO DEL PROMPT ORIGINAL.
        MANTEN TODAS Y CADA UNA de las variables entre llaves (ejemplo: {{ejemplo}}) exactamente intactas.
        Tu respuesta debe ser EXCLUSIVAMENTE el texto de la alternativa, sin títulos, explicaciones, comillas ni comentarios extra. Dámelo plano.

        PROMPT ORIGINAL:
        \\(cleanContent)
        \"\"\"

        Task {
            do {
                let response = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await MainActor.run {
                    self.isGeneratingAlternativeDirect = false
                    if !cleanedResponse.isEmpty {
                        withAnimation(.spring()) {
                            if self.alternatives.isEmpty {
                                self.alternatives.append(cleanedResponse)
                            } else {
                                self.alternatives.append(cleanedResponse)
                            }
                            self.showAlternativeField = true
                        }
                        HapticService.shared.playSuccess()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingAlternativeDirect = false
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error, language: preferences.language)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { self.branchMessage = nil }
                    }
                }
            }
        }
    }
"""

vm_content = vm_content.replace("    func autoCategorizePrompt", new_method_vm + "\n    func autoCategorizePrompt")
with open(path_vm, "w") as f:
    f.write(vm_content)


path_view = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path_view, "r") as f:
    view_content = f.read()

# Replace generateAlternativeDirect in View
old_func = r"private func generateAlternativeDirect\(\) \{.*?\n        Task \{.*?\n        \}\n    \}"
new_func = """private func generateAlternativeDirect() {
        let vm = NewPromptViewModel()
        vm.content = self.content
        vm.alternatives = self.alternatives
        
        vm.generateAlternativeDirect(preferences: preferences)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                self.alternatives = vm.alternatives
                self.branchMessage = vm.branchMessage
                self.isGeneratingAlternativeDirect = vm.isGeneratingAlternativeDirect
                if vm.showAlternativeField { self.showAlternativeField = true }
                
                if !vm.isGeneratingAlternativeDirect {
                    timer.invalidate()
                }
            }
        }
    }"""

view_content = re.sub(old_func, new_func, view_content, flags=re.DOTALL)
with open(path_view, "w") as f:
    f.write(view_content)
