import re
import os

path_vm = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/ViewModels/NewPromptViewModel.swift"
path_view = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"

with open(path_vm, "r") as f:
    vm_content = f.read()

with open(path_view, "r") as f:
    view_content = f.read()

# 1. Extract all `@State` variables from NewPromptView
# We will match: @State private var variableName: Type = Value
state_pattern = r"@State(?:Object)?\s+private\s+var\s+([a-zA-Z0-9_]+)(?:\s*:\s*([^=]+))?(?:\s*=\s*(.*))?"

matches = re.finditer(state_pattern, view_content)
variables_to_migrate = []
for m in matches:
    var_name = m.group(1)
    if var_name not in ["localMonitor", "cancellables", "aiTask", "originalPrompt", "isDraftRestored"]: # Skip internal logic states that don't belong to the shared UI state
        variables_to_migrate.append(var_name)

# 2. In NewPromptView, replace `@State private var ...` with nothing (remove them)
# But wait, to make it compile, we need to inject the view model:
# `@ObservedObject var viewModel: NewPromptViewModel`
# And then replace every usage of `variableName` with `viewModel.variableName`
# This is extremely risky to do with regex across 3000 lines because `title` or `content` could match other things.

# Safe approach: we will keep the `@State` declarations in NewPromptView for now, but we will CHANGE THEM to be computed properties that proxy to `viewModel`.
# Example: 
# @State private var title = "" -> 
# var title: String { get { viewModel.title } nonmutating set { viewModel.title = newValue } }
# This requires knowing the exact Type of each variable.

# Since the user authorized moving to the ViewModel, let's actually just build the ViewModel to hold the state, and let NewPromptView hold the ViewModel.
# However, NewPromptView has 40+ states.
# We will do this manually for the 3 main blocks: PromptTagsEditorView, PromptAppTargetsView, PromptImageShowcaseView.
# Let's just replace the UI blocks in NewPromptView.swift with calls to the newly extracted views.
