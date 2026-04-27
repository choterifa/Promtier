import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(filepath, "r") as f:
    content = f.read()

# Remove bindings passed to ZenEditorView
content = re.sub(r'                    insertionRequest: \$uiState\.insertionRequest,\n                    replaceSnippetRequest: \$uiState\.replaceSnippetRequest,\n                    uiState\.showSnippets: \$uiState\.showSnippets,\n                    uiState\.snippetSearchQuery: \$uiState\.snippetSearchQuery,\n                    snippetSelectedIndex: \$uiState\.snippetSelectedIndex,\n                    triggerSnippetSelection: \$uiState\.triggerSnippetSelection,\n                    uiState\.showVariables: \$uiState\.showVariables,\n                    variablesSelectedIndex: \$uiState\.variablesSelectedIndex,\n                    triggerVariablesSelection: \$uiState\.triggerVariablesSelection,\n                    triggerAIRequest: \$uiState\.triggerAIRequest,\n                    isAIActive: \$uiState\.isAIActive,\n                    isAIGenerating: Binding\([\s\S]*?\),\n                    selectedRange: zenBindingSelection,\n                    aiResult: zenBindingAIResult,\n', '', content)

# Remove bindings passed to SecondaryEditorCard for alternativeRow
content = re.sub(r'            insertionRequest: \$uiState\.insertionRequest,\n            replaceSnippetRequest: \$uiState\.replaceSnippetRequest,\n            uiState\.showSnippets: \$uiState\.showSnippets,\n            uiState\.snippetSearchQuery: \$uiState\.snippetSearchQuery,\n            snippetSelectedIndex: \$uiState\.snippetSelectedIndex,\n            triggerSnippetSelection: \$uiState\.triggerSnippetSelection,\n            uiState\.showVariables: \$uiState\.showVariables,\n            variablesSelectedIndex: \$uiState\.variablesSelectedIndex,\n            triggerVariablesSelection: \$uiState\.triggerVariablesSelection,\n            triggerAIRequest: \$uiState\.triggerAIRequest,\n            isAIActive: \$uiState\.isAIActive,\n            isAIGenerating: Binding\([\s\S]*?\),\n            selectedRange: Binding\([\s\S]*?\),\n            aiResult: Binding\([\s\S]*?\),\n', 
                 r'            isAIGenerating: Binding(\n                get: { uiState.activeGeneratingID == "alt-\\(index)" },\n                set: { val in uiState.activeGeneratingID = val ? "alt-\\(index)" : nil }\n            ),\n', content)


with open(filepath, "w") as f:
    f.write(content)

print("Final cleanup done")
