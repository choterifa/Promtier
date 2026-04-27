import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Components/NewPromptOverlaysManager.swift"
with open(filepath, "r") as f:
    content = f.read()

content = content.replace("snippetSearchQuery", "uiState.snippetSearchQuery")
content = content.replace("$snippetSelectedIndex", "$uiState.snippetSelectedIndex")
content = content.replace("$triggerSnippetSelection", "$uiState.triggerSnippetSelection")
content = content.replace("$variablesSelectedIndex", "$uiState.variablesSelectedIndex")
content = content.replace("$triggerVariablesSelection", "$uiState.triggerVariablesSelection")

# wait, snippetSearchQuery was replaced as `uiState.uiState.snippetSearchQuery` maybe if it was already replaced?
content = content.replace("uiState.uiState.", "uiState.")

with open(filepath, "w") as f:
    f.write(content)

print("NewPromptOverlaysManager fixed2")
