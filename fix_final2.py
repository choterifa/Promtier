import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(filepath, "r") as f:
    content = f.read()

content = content.replace("selectedRange = nil", "uiState.selectedRange = nil")
content = content.replace("selectedNegativeRange = nil", "uiState.selectedRange = nil")
content = content.replace("selectedNegativeRange", "uiState.selectedRange")
content = content.replace("aiResult = nil", "uiState.aiResult = nil")
content = content.replace("aiNegativeResult = nil", "uiState.aiResult = nil")
content = content.replace("aiNegativeResult", "uiState.aiResult")

content = re.sub(r'(EditorCard\([\s\S]*?)(isAutocompleting:)', r'\1isAIGenerating: Binding(\n                    get: { uiState.activeGeneratingID == "main" },\n                    set: { val in uiState.activeGeneratingID = val ? "main" : nil }\n                ),\n                \2', content)

with open(filepath, "w") as f:
    f.write(content)

print("Final cleanup 2 done")
