import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(filepath, "r") as f:
    content = f.read()

# Fix $uiState.uiState
content = content.replace("$uiState.uiState.", "$uiState.")
content = content.replace("uiState.uiState.", "uiState.")

# Remove parameters from NewPromptOverlaysManager call inside NewPromptView
# Wait! I didn't see NewPromptOverlaysManager in NewPromptView. Let's find it.
# If NewPromptOverlaysManager is in NewPromptView, I need to strip the args.
content = re.sub(r'                NewPromptOverlaysManager\([\s\S]*?showParticles: \$showParticles,\n                currentCategoryColor: currentCategoryColor,\n                showingMagicOptions: \$showingMagicOptions,\n                magicTarget: \$magicTarget,\n                magicCommand: \$magicCommand,\n                executeMagicWithCommand: executeMagicWithCommand,\n                showingCreationOptions: \$showingCreationOptions,\n                executeAutocomplete: executeAutocomplete\n            \)',
                 '                NewPromptOverlaysManager(\n                zenTarget: $zenTarget,\n                showingZenEditor: $showingZenEditor,\n                zenBindingTitle: $viewModel.title,\n                zenBindingContent: $viewModel.content,\n                zenBindingSelection: $uiState.selectedRange,\n                zenBindingAIResult: $uiState.aiResult,\n                showingPremiumFor: $viewModel.showingPremiumFor,\n                originalPrompt: viewModel.originalPrompt,\n                branchMessage: $viewModel.branchMessage,\n                showParticles: $showParticles,\n                currentCategoryColor: currentCategoryColor,\n                showingMagicOptions: $viewModel.showingMagicOptions,\n                magicTarget: $viewModel.magicTarget,\n                magicCommand: $viewModel.magicCommand,\n                executeMagicWithCommand: executeMagicWithCommand,\n                showingCreationOptions: $viewModel.showingCreationOptions,\n                executeAutocomplete: executeAutocomplete\n            )', content)

# But what if that regex didn't match? Let's just fix the specific variables that were reported:
content = content.replace("showSnippets)", "uiState.showSnippets)")
content = content.replace("showVariables)", "uiState.showVariables)")
content = content.replace("showSnippets:", "showSnippets:") # don't want to break labels if not needed
# Let's just do bulk replacement of the variable names:
content = content.replace("showSnippets", "uiState.showSnippets")
content = content.replace("showVariables", "uiState.showVariables")
content = content.replace("snippetSearchQuery", "uiState.snippetSearchQuery")
content = content.replace("$insertionRequest", "$uiState.insertionRequest")
content = content.replace("$replaceSnippetRequest", "$uiState.replaceSnippetRequest")
content = content.replace("$variablesSelectedIndex", "$uiState.variablesSelectedIndex")
content = content.replace("$triggerVariablesSelection", "$uiState.triggerVariablesSelection")
content = content.replace("$triggerAIRequest", "$uiState.triggerAIRequest")
content = content.replace("$isAIActive", "$uiState.isAIActive")

# Ensure no double prefix
content = content.replace("uiState.uiState.", "uiState.")
content = content.replace("$uiState.uiState.", "$uiState.")

with open(filepath, "w") as f:
    f.write(content)

print("NewPromptView fixed again")
