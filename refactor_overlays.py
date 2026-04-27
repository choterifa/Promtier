import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Components/NewPromptOverlaysManager.swift"
with open(filepath, "r") as f:
    content = f.read()

# Add @EnvironmentObject
content = re.sub(r'(@EnvironmentObject var preferences: PreferencesManager)', r'\1\n    @EnvironmentObject var uiState: EditorUIState', content)

# Remove bindings
bindings_to_remove = [
    "    @Binding var activeGeneratingID: String?\n",
    "    @Binding var insertionRequest: String?\n",
    "    @Binding var replaceSnippetRequest: String?\n",
    "    @Binding var showSnippets: Bool\n",
    "    @Binding var snippetSearchQuery: String\n",
    "    @Binding var snippetSelectedIndex: Int\n",
    "    @Binding var triggerSnippetSelection: Bool\n",
    "    @Binding var showVariables: Bool\n",
    "    @Binding var variablesSelectedIndex: Int\n",
    "    @Binding var triggerVariablesSelection: Bool\n",
    "    @Binding var triggerAIRequest: String?\n",
    "    @Binding var isAIActive: Bool\n",
]
for b in bindings_to_remove:
    content = content.replace(b, "")

# Remove ZenEditorView args
content = re.sub(r'                    insertionRequest: \$insertionRequest,\n                    replaceSnippetRequest: \$replaceSnippetRequest,\n                    showSnippets: \$showSnippets,\n                    snippetSearchQuery: \$snippetSearchQuery,\n                    snippetSelectedIndex: \$snippetSelectedIndex,\n                    triggerSnippetSelection: \$triggerSnippetSelection,\n                    showVariables: \$showVariables,\n                    variablesSelectedIndex: \$variablesSelectedIndex,\n                    triggerVariablesSelection: \$triggerVariablesSelection,\n                    triggerAIRequest: \$triggerAIRequest,\n                    isAIActive: \$isAIActive,\n                    isAIGenerating: Binding\([\s\S]*?\),\n', '', content)

# Remove ZenEditorView binding args
content = re.sub(r'                    selectedRange: zenBindingSelection,\n                    aiResult: zenBindingAIResult,\n', '', content)

# Replace usage
content = content.replace("showSnippets: $showSnippets", "showSnippets: $uiState.showSnippets")
content = content.replace("snippetSearchQuery: $snippetSearchQuery", "snippetSearchQuery: $uiState.snippetSearchQuery")
content = content.replace("snippetSelectedIndex: $snippetSelectedIndex", "snippetSelectedIndex: $uiState.snippetSelectedIndex")
content = content.replace("triggerSnippetSelection: $triggerSnippetSelection", "triggerSnippetSelection: $uiState.triggerSnippetSelection")

content = content.replace("replaceSnippetRequest = ", "uiState.replaceSnippetRequest = ")
content = content.replace("insertionRequest = ", "uiState.insertionRequest = ")

content = content.replace("showSnippets =", "uiState.showSnippets =")
content = content.replace("!showSnippets", "!uiState.showSnippets")
content = content.replace("showSnippets ?", "uiState.showSnippets ?")
content = content.replace("showSnippets)", "uiState.showSnippets)")
content = content.replace("value: showSnippets)", "value: uiState.showSnippets)")

content = content.replace("showVariables =", "uiState.showVariables =")
content = content.replace("!showVariables", "!uiState.showVariables")
content = content.replace("showVariables ?", "uiState.showVariables ?")
content = content.replace("showVariables)", "uiState.showVariables)")
content = content.replace("value: showVariables)", "value: uiState.showVariables)")

with open(filepath, "w") as f:
    f.write(content)

print("NewPromptOverlaysManager refactored")
