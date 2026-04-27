import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/SecondaryEditorCard.swift"
with open(filepath, "r") as f:
    content = f.read()

content = re.sub(r'plainText: \$plainTextContent,\n\s*', '', content)

with open(filepath, "w") as f:
    f.write(content)

print("SecondaryEditorCard plainText fixed")
