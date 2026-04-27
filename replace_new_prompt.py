import re

filepath = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(filepath, "r") as f:
    content = f.read()

# Replace local bindings with uiState instance
content = re.sub(r'(@State var isSaving = false)', r'\1\n    @StateObject private var uiState = EditorUIState()', content)

bindings_to_remove = [
    "    @State var insertionRequest: String? = nil\n",
    "    @State var replaceSnippetRequest: String? = nil\n",
    "    @State var showSnippets: Bool = false\n",
    "    @State var snippetSearchQuery: String = \"\"\n",
    "    @State var snippetSelectedIndex: Int = 0\n",
    "    @State var triggerSnippetSelection: Bool = false\n\n",
    "    @State var showVariables: Bool = false\n",
    "    @State var variablesSelectedIndex: Int = 0\n",
    "    @State var triggerVariablesSelection: Bool = false\n\n",
    "    @State var triggerAIRequest: String? = nil\n",
    "    @State var selectedRange: NSRange? = nil\n",
    "    @State var selectedNegativeRange: NSRange? = nil\n",
    "    @State var aiResult: AIResult? = nil\n",
    "    @State var aiNegativeResult: AIResult? = nil\n",
    "    @State var isAIActive: Bool = false\n",
    "    @State var activeGeneratingID: String? = nil\n",
]
for b in bindings_to_remove:
    content = content.replace(b, "")

# Add .environmentObject(uiState) to the main VStack body
content = re.sub(r'(\.background\(backgroundView\))', r'\1\n        .environmentObject(uiState)', content)

# Replace usage in EditorCard and PromptAdvancedFieldsView parameters
# EditorCard has things like `insertionRequest: $insertionRequest` but we removed those parameters from EditorCard!
# So we need to REMOVE the passed parameters from NewPromptView when calling EditorCard and PromptAdvancedFieldsView

# Remove parameters from EditorCard instantiation
content = re.sub(r'                insertionRequest: \$insertionRequest,\n                replaceSnippetRequest: \$replaceSnippetRequest,\n                showSnippets: \$showSnippets,\n                snippetSearchQuery: \$snippetSearchQuery,\n                snippetSelectedIndex: \$snippetSelectedIndex,\n                triggerSnippetSelection: \$triggerSnippetSelection,\n                showVariables: \$showVariables,\n                variablesSelectedIndex: \$variablesSelectedIndex,\n                triggerVariablesSelection: \$triggerVariablesSelection,\n                triggerAIRequest: \$triggerAIRequest,\n                isAIActive: \$isAIActive,\n                isAIGenerating: .*?,\n                isAutocompleting: isAutocompleting,\n', r'                isAutocompleting: isAutocompleting,\n', content, flags=re.DOTALL)

content = re.sub(r'                selectedRange: \$selectedRange,\n                aiResult: \$aiResult,\n', '', content)

# Remove parameters from PromptAdvancedFieldsView instantiation
content = re.sub(r'                    insertionRequest: \$insertionRequest,\n                    replaceSnippetRequest: \$replaceSnippetRequest,\n                    showSnippets: \$showSnippets,\n                    snippetSearchQuery: \$snippetSearchQuery,\n                    snippetSelectedIndex: \$snippetSelectedIndex,\n                    triggerSnippetSelection: \$triggerSnippetSelection,\n                    showVariables: \$showVariables,\n                    variablesSelectedIndex: \$variablesSelectedIndex,\n                    triggerVariablesSelection: \$triggerVariablesSelection,\n                    triggerAIRequest: \$triggerAIRequest,\n                    isAIActive: \$isAIActive,\n                    activeGeneratingID: \$activeGeneratingID,\n                    selectedNegativeRange: \$selectedNegativeRange,\n                    aiNegativeResult: \$aiNegativeResult,\n', '', content)

# Remove parameters from SecondaryEditorCard (alternatives) instantiation
content = re.sub(r'                                insertionRequest: \$insertionRequest,\n                                replaceSnippetRequest: \$replaceSnippetRequest,\n                                showSnippets: \$showSnippets,\n                                snippetSearchQuery: \$snippetSearchQuery,\n                                snippetSelectedIndex: \$snippetSelectedIndex,\n                                triggerSnippetSelection: \$triggerSnippetSelection,\n                                showVariables: \$showVariables,\n                                variablesSelectedIndex: \$variablesSelectedIndex,\n                                triggerVariablesSelection: \$triggerVariablesSelection,\n                                triggerAIRequest: \$triggerAIRequest,\n                                isAIActive: \$isAIActive,\n                                isAIGenerating: .*?,\n                                selectedRange: .*?,\n                                aiResult: .*?,\n', '', content, flags=re.DOTALL)

# Now fix any local references to these variables in NewPromptView
content = content.replace("activeGeneratingID =", "uiState.activeGeneratingID =")
content = content.replace("activeGeneratingID == ", "uiState.activeGeneratingID == ")

content = content.replace("insertionRequest = ", "uiState.insertionRequest = ")
content = content.replace("replaceSnippetRequest = ", "uiState.replaceSnippetRequest = ")
content = content.replace("$showSnippets", "$uiState.showSnippets")
content = content.replace("showSnippets = ", "uiState.showSnippets = ")
content = content.replace("showSnippets ?", "uiState.showSnippets ?")
content = content.replace("!showSnippets", "!uiState.showSnippets")

content = content.replace("$showVariables", "$uiState.showVariables")
content = content.replace("showVariables = ", "uiState.showVariables = ")
content = content.replace("showVariables ?", "uiState.showVariables ?")
content = content.replace("!showVariables", "!uiState.showVariables")

content = content.replace("$snippetSearchQuery", "$uiState.snippetSearchQuery")
content = content.replace("$snippetSelectedIndex", "$uiState.snippetSelectedIndex")
content = content.replace("$triggerSnippetSelection", "$uiState.triggerSnippetSelection")

content = content.replace("snippetSearchQuery =", "uiState.snippetSearchQuery =")
content = content.replace("snippetSelectedIndex =", "uiState.snippetSelectedIndex =")

content = content.replace("selectedRange =", "uiState.selectedRange =")

with open(filepath, "w") as f:
    f.write(content)

print("NewPromptView refactored")
