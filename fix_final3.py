import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(filepath, "r") as f:
    content = f.read()

content = content.replace("selectedRange = ", "uiState.selectedRange = ")
content = content.replace("aiResult = ", "uiState.aiResult = ")

content = content.replace("activeGeneratingID: $uiState.activeGeneratingID,", "")

with open(filepath, "w") as f:
    f.write(content)

filepath_adv = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptAdvancedFieldsView.swift"
with open(filepath_adv, "r") as f:
    content = f.read()

content = content.replace("activeGeneratingID: $uiState.activeGeneratingID,", "")

with open(filepath_adv, "w") as f:
    f.write(content)

print("Final cleanup 3 done")
