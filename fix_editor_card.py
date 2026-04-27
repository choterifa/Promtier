import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/EditorCard.swift"
with open(filepath, "r") as f:
    content = f.read()

content = content.replace("self.aiResult = $0", "self.uiState.aiResult = $0")

with open(filepath, "w") as f:
    f.write(content)

print("EditorCard fixed")
