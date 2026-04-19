import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

# Instead of modifying the massive view, let's inform the user that it's too complex to safely regex replace 30 variables 
# 400+ times without compiling errors, so we will use a safe Binding mapping approach to extract the Core View, 
# or just migrate the view step by step manually.
