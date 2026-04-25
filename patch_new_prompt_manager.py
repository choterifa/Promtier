import re
import sys

try:
    with open('Promtier/Components/NewPromptOverlaysManager.swift', 'r') as f:
        content = f.read()

    # 3. Replace snippetOverlay
    snippet_full_old = r'''    private var snippetOverlay: some View \{\s*VStack \{\s*Spacer\(\)\s*if !preferences\.isPremiumActive \{\s*PremiumUpsellView\(.*?\)\s*\.cornerRadius\(24\)\s*\.shadow\(color: Color\.black\.opacity\(0\.15\), radius: 30, x: 0, y: 15\)\s*\.padding\(\.bottom, 24\)\s*\} else \{\s*SnippetsPopupList\(\s*query: snippetSearchQuery,\s*selectedIndex: \$snippetSelectedIndex,\s*triggerSelection: \$triggerSnippetSelection,\s*onSelect: \{ snippet in\s*replaceSnippetRequest = snippet\.content\s*\},\s*onDismiss: \{\s*withAnimation \{ showSnippets = false \}\s*\}\s*\)\s*\.padding\(\.bottom, 24\)\s*\}\s*\}\s*\}'''

    snippet_full_new = '''    private var snippetOverlay: some View {
        VStack {
            Spacer()
            if preferences.isPremiumActive {
                SnippetsPopupList(
                    query: snippetSearchQuery,
                    selectedIndex: $snippetSelectedIndex,
                    triggerSelection: $triggerSnippetSelection,
                    onSelect: { snippet in
                        replaceSnippetRequest = snippet.content
                    },
                    onDismiss: {
                        withAnimation { showSnippets = false }
                    }
                )
                .padding(.bottom, 24)
            }
        }
    }'''
    content = re.sub(snippet_full_old, snippet_full_new, content, flags=re.DOTALL)

    # 4. Replace variablesOverlay
    var_full_old = r'''    private var variablesOverlay: some View \{\s*VStack \{\s*Spacer\(\)\s*if !preferences\.isPremiumActive \{\s*PremiumUpsellView\(.*?\)\s*\.cornerRadius\(24\)\s*\.shadow\(color: Color\.black\.opacity\(0\.15\), radius: 30, x: 0, y: 15\)\s*\.padding\(\.bottom, 24\)\s*\} else \{\s*VariablesPopupList\(\s*selectedIndex: \$variablesSelectedIndex,\s*triggerSelection: \$triggerVariablesSelection,\s*onSelect: \{ option in\s*insertionRequest = option\.insertionText\s*withAnimation \{ showVariables = false \}\s*\},\s*onDismiss: \{\s*withAnimation \{ showVariables = false \}\s*\}\s*\)\s*\.padding\(\.bottom, 24\)\s*\}\s*\}\s*\}'''
    
    var_full_new = '''    private var variablesOverlay: some View {
        VStack {
            Spacer()
            if preferences.isPremiumActive {
                VariablesPopupList(
                    selectedIndex: $variablesSelectedIndex,
                    triggerSelection: $triggerVariablesSelection,
                    onSelect: { option in
                        insertionRequest = option.insertionText
                        withAnimation { showVariables = false }
                    },
                    onDismiss: {
                        withAnimation { showVariables = false }
                    }
                )
                .padding(.bottom, 24)
            }
        }
    }'''
    content = re.sub(var_full_old, var_full_new, content, flags=re.DOTALL)

    with open('Promtier/Components/NewPromptOverlaysManager.swift', 'w') as f:
        f.write(content)
        
    print("Success")
except Exception as e:
    print(f"Error: {e}")

