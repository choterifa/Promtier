import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

# Define the state variables to migrate to viewModel
state_vars = [
    "title", "content", "negativePrompt", "alternatives", 
    "promptDescription", "selectedFolder", "isFavorite", "selectedIcon", 
    "showcaseImages", "isSaving", "tags", "newTag", 
    "targetAppBundleIDs", "customShortcut",
    "showingPremiumFor", "showingMagicOptions", "branchMessage",
    "isAutocompleting", "isCategorizing", "showNegativeField", 
    "showAlternativeField", "magicCommand", "magicTarget", "isGeneratingAlternativeDirect"
]

# We need to replace all usages of these variables with viewModel.variableName
# But we have to be careful not to replace them when they are part of another word, or arguments
# A safe way is to replace word boundaries. 
# Better yet, since we are doing it in chunks, let's just move the methods into NewPromptViewModel, 
# and in NewPromptView, we just call the methods from viewModel and pass the required state as Bindings?
# NO, MVVM means the ViewModel holds the state.
