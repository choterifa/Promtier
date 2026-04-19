import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    content = f.read()

# Instead of a dangerous global replace, I will move the AI functions into an extension of NewPromptView or a helper class first, or carefully add them to the ViewModel.
