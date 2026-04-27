import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/ZenEditorView.swift"
with open(filepath, "r") as f:
    content = f.read()

# Add @EnvironmentObject var uiState: EditorUIState
content = re.sub(r'(@EnvironmentObject var preferences: PreferencesManager)', r'\1\n    @EnvironmentObject var uiState: EditorUIState', content)

# Remove bindings
bindings_to_remove = [
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
    "    @Binding var isAIGenerating: Bool\n",
    "    @Binding var selectedRange: NSRange?\n",
    "    @Binding var aiResult: AIResult?\n",
]
for b in bindings_to_remove:
    content = content.replace(b, "")

# Replace usage
content = content.replace("insertionRequest: $insertionRequest", "insertionRequest: $uiState.insertionRequest")
content = content.replace("replaceSnippetRequest: $replaceSnippetRequest", "replaceSnippetRequest: $uiState.replaceSnippetRequest")
content = content.replace("triggerAIRequest: $triggerAIRequest", "triggerAIRequest: $uiState.triggerAIRequest")
content = content.replace("isAIActive: $isAIActive", "isAIActive: $uiState.isAIActive")
content = content.replace("selectedRange: $selectedRange", "selectedRange: $uiState.selectedRange")
content = content.replace("aiResult: $aiResult", "aiResult: $uiState.aiResult")
content = content.replace("showSnippets: $showSnippets", "showSnippets: $uiState.showSnippets")
content = content.replace("snippetSearchQuery: $snippetSearchQuery", "snippetSearchQuery: $uiState.snippetSearchQuery")
content = content.replace("snippetSelectedIndex: $snippetSelectedIndex", "snippetSelectedIndex: $uiState.snippetSelectedIndex")
content = content.replace("triggerSnippetSelection: $triggerSnippetSelection", "triggerSnippetSelection: $uiState.triggerSnippetSelection")
content = content.replace("showVariables: $showVariables", "showVariables: $uiState.showVariables")
content = content.replace("variablesSelectedIndex: $variablesSelectedIndex", "variablesSelectedIndex: $uiState.variablesSelectedIndex")
content = content.replace("triggerVariablesSelection: $triggerVariablesSelection", "triggerVariablesSelection: $uiState.triggerVariablesSelection")

content = content.replace("showVariables.toggle()", "uiState.showVariables.toggle()")
content = content.replace("variablesSelectedIndex =", "uiState.variablesSelectedIndex =")

with open(filepath, "w") as f:
    f.write(content)

print("ZenEditorView refactored")
