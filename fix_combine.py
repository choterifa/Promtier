import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/ViewModels/EditorUIState.swift"
with open(filepath, "r") as f:
    content = f.read()

if "import Combine" not in content:
    content = content.replace("import SwiftUI\n", "import SwiftUI\nimport Combine\n")

with open(filepath, "w") as f:
    f.write(content)

print("Combine imported")
