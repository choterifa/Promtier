import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

# Replace autocompletePromptContent
p1 = r"private func autocompletePromptContent\(\) \{.*?\n        Task \{.*?\n        \}\n    \}"
rep1 = """private func autocompletePromptContent() {
        let vm = NewPromptViewModel()
        vm.title = self.title
        vm.content = self.content
        vm.promptDescription = self.promptDescription
        vm.selectedFolder = self.selectedFolder
        vm.negativePrompt = self.negativePrompt
        vm.alternatives = self.alternatives
        
        vm.autocompletePromptContent(preferences: preferences, promptService: promptService)
        
        // Simular un 'Binding' temporal manual hasta que se complete el refactor completo a MVVM (Paso 14)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                self.title = vm.title
                self.content = vm.content
                self.promptDescription = vm.promptDescription
                self.selectedFolder = vm.selectedFolder
                self.negativePrompt = vm.negativePrompt
                self.alternatives = vm.alternatives
                if vm.showNegativeField { self.showNegativeField = true }
                if vm.showAlternativeField { self.showAlternativeField = true }
                self.branchMessage = vm.branchMessage
                self.isAutocompleting = vm.isAutocompleting
                self.showingMagicOptions = vm.showingMagicOptions
                self.showingPremiumFor = vm.showingPremiumFor
                
                if !vm.isAutocompleting {
                    timer.invalidate()
                }
            }
        }
    }"""
text = re.sub(p1, rep1, text, flags=re.DOTALL)

# Replace executeMagicWithCommand
p2 = r"private func executeMagicWithCommand\(\) \{.*?\n        Task \{.*?\n        \}\n    \}"
rep2 = """private func executeMagicWithCommand() {
        let vm = NewPromptViewModel()
        vm.title = self.title
        vm.content = self.content
        vm.promptDescription = self.promptDescription
        vm.negativePrompt = self.negativePrompt
        vm.alternatives = self.alternatives
        vm.magicCommand = self.magicCommand
        vm.magicTarget = self.magicTarget
        
        vm.executeMagicWithCommand(preferences: preferences)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                self.title = vm.title
                self.content = vm.content
                self.promptDescription = vm.promptDescription
                self.negativePrompt = vm.negativePrompt
                self.alternatives = vm.alternatives
                if vm.showNegativeField { self.showNegativeField = true }
                if vm.showAlternativeField { self.showAlternativeField = true }
                self.branchMessage = vm.branchMessage
                self.isAutocompleting = vm.isAutocompleting
                self.showingMagicOptions = vm.showingMagicOptions
                self.showingPremiumFor = vm.showingPremiumFor
                
                if !vm.isAutocompleting {
                    timer.invalidate()
                }
            }
        }
    }"""
text = re.sub(p2, rep2, text, flags=re.DOTALL)

# Replace autoCategorizePrompt
p3 = r"private func autoCategorizePrompt\(\) \{.*?\n        Task \{.*?\n        \}\n    \}"
rep3 = """private func autoCategorizePrompt() {
        let vm = NewPromptViewModel()
        vm.title = self.title
        vm.content = self.content
        vm.selectedFolder = self.selectedFolder
        
        vm.autoCategorizePrompt(preferences: preferences, promptService: promptService)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                self.selectedFolder = vm.selectedFolder
                self.branchMessage = vm.branchMessage
                self.isCategorizing = vm.isCategorizing
                self.showingPremiumFor = vm.showingPremiumFor
                
                if !vm.isCategorizing {
                    timer.invalidate()
                }
            }
        }
    }"""
text = re.sub(p3, rep3, text, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(text)
