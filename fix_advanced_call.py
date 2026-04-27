import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptAdvancedFieldsView.swift"
with open(filepath, "r") as f:
    content = f.read()

content = re.sub(r'                    insertionRequest: \$uiState.insertionRequest,\n                    replaceSnippetRequest: \$uiState.replaceSnippetRequest,\n                    showSnippets: \$uiState.showSnippets,\n                    snippetSearchQuery: \$uiState.snippetSearchQuery,\n                    snippetSelectedIndex: \$uiState.snippetSelectedIndex,\n                    triggerSnippetSelection: \$uiState.triggerSnippetSelection,\n                    showVariables: \$uiState.showVariables,\n                    variablesSelectedIndex: \$uiState.variablesSelectedIndex,\n                    triggerVariablesSelection: \$uiState.triggerVariablesSelection,\n                    triggerAIRequest: \$uiState.triggerAIRequest,\n                    isAIActive: \$uiState.isAIActive,\n                    isAIGenerating: Binding\(.*?\),\n                    selectedRange: \$uiState.selectedRange,\n                    aiResult: \$uiState.aiResult,\n', '', content, flags=re.DOTALL)

with open(filepath, "w") as f:
    f.write(content)

print("PromptAdvancedFieldsView instantiation fixed")
