content = File.read("Promtier/Views/NewPromptView.swift")

# 1. Add view model right after onClose
view_model_decl = "    var prompt: Prompt?\n    var onClose: () -> Void\n\n    @StateObject private var viewModel = NewPromptViewModel(service: PromptService())\n"
content.sub!(/    var prompt: Prompt\?\n    var onClose: \(\) -> Void\n/, view_model_decl)

# Since PromptService doesn't have an empty initializer by default, let's inject it from environment.
# Actually, best if we capture the environment object or initialize in init... let's check init first:
