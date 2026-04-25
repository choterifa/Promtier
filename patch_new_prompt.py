import re
import sys

try:
    with open('Promtier/Views/NewPromptView.swift', 'r') as f:
        content = f.read()

    # 1. Remove premiumSheetItem
    content = re.sub(
        r'''    var premiumSheetItem: Binding<IdentifiableString\?> \{\s*Binding\(\s*get: \{ showingPremiumFor\.map \{ IdentifiableString\(value: \$0\) \} \},\s*set: \{ showingPremiumFor = \$0\?\.value \}\s*\)\s*\}\n\n''',
        '',
        content
    )

    # 2. Remove .sheet(item: premiumSheetItem)
    content = re.sub(
        r'''                \.sheet\(item: premiumSheetItem\) \{ item in\s*PremiumUpsellView\(featureName: item\.value\)\s*\}\n''',
        '',
        content
    )

    # 3. Replace snippetOverlay
    snippet_old = r'''    var snippetOverlay: some View \{\s*VStack \{\s*Spacer\(\)\s*if !preferences\.isPremiumActive \{\s*PremiumUpsellView\(\s*featureName: "quick_snippets"\.localized\(for: preferences\.language\),\s*onCancel: \{\s*withAnimation \{ showSnippets = false \}\s*\}\s*\)\s*\.cornerRadius\(24\)\s*\.shadow\(color: Color\.black\.opacity\(0\.15\), radius: 30, x: 0, y: 15\)\s*\.padding\(\.bottom, 24\)\s*\} else \{\s*SnippetsPopupList\('''
    
    snippet_new = r'''    var snippetOverlay: some View {
        VStack {
            Spacer()
            if preferences.isPremiumActive {
                SnippetsPopupList('''
    
    content = re.sub(snippet_old, snippet_new, content)
    
    # And fix the closing brace for snippetOverlay
    # Wait, using regex for the whole block is easier:
    snippet_full_old = r'''    var snippetOverlay: some View \{\s*VStack \{\s*Spacer\(\)\s*if !preferences\.isPremiumActive \{\s*PremiumUpsellView\(.*?\)\s*\.cornerRadius\(24\)\s*\.shadow\(color: Color\.black\.opacity\(0\.15\), radius: 30, x: 0, y: 15\)\s*\.padding\(\.bottom, 24\)\s*\} else \{\s*SnippetsPopupList\(\s*query: snippetSearchQuery,\s*selectedIndex: \$snippetSelectedIndex,\s*triggerSelection: \$triggerSnippetSelection,\s*onSelect: \{ snippet in\s*replaceSnippetRequest = snippet\.content\s*\},\s*onDismiss: \{\s*withAnimation \{ showSnippets = false \}\s*\}\s*\)\s*\.padding\(\.bottom, 24\)\s*\}\s*\}\s*\}'''

    snippet_full_new = '''    var snippetOverlay: some View {
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
    var_full_old = r'''    var variablesOverlay: some View \{\s*VStack \{\s*Spacer\(\)\s*if !preferences\.isPremiumActive \{\s*PremiumUpsellView\(.*?\)\s*\.cornerRadius\(24\)\s*\.shadow\(color: Color\.black\.opacity\(0\.15\), radius: 30, x: 0, y: 15\)\s*\.padding\(\.bottom, 24\)\s*\} else \{\s*VariablesPopupList\(\s*selectedIndex: \$variablesSelectedIndex,\s*triggerSelection: \$triggerVariablesSelection,\s*onSelect: \{ option in\s*insertionRequest = option\.insertionText\s*withAnimation \{ showVariables = false \}\s*\},\s*onDismiss: \{\s*withAnimation \{ showVariables = false \}\s*\}\s*\)\s*\.padding\(\.bottom, 24\)\s*\}\s*\}\s*\}'''
    
    var_full_new = '''    var variablesOverlay: some View {
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

    # 5. Add onChange modifiers
    # Let's add them right after .sheet(item: $diffComparison)
    on_changes = '''                .sheet(item: $diffComparison) { comparison in
                    DiffView(
                        text1: comparison.text1,
                        text2: comparison.text2,
                        title1: comparison.title1,
                        title2: comparison.title2
                    )
                }
                .onChange(of: showingPremiumFor) { _, newValue in
                    if newValue != nil {
                        MenuBarManager.shared.premiumUpsellFeature = "Promtier Pro"
                        showingPremiumFor = nil
                    }
                }
                .onChange(of: showSnippets) { _, newValue in
                    if newValue && !preferences.isPremiumActive {
                        showSnippets = false
                        MenuBarManager.shared.premiumUpsellFeature = "Promtier Pro"
                    }
                }
                .onChange(of: showVariables) { _, newValue in
                    if newValue && !preferences.isPremiumActive {
                        showVariables = false
                        MenuBarManager.shared.premiumUpsellFeature = "Promtier Pro"
                    }
                }'''
    
    content = content.replace(
        '''.sheet(item: $diffComparison) { comparison in
                    DiffView(
                        text1: comparison.text1,
                        text2: comparison.text2,
                        title1: comparison.title1,
                        title2: comparison.title2
                    )
                }''',
        on_changes
    )

    with open('Promtier/Views/NewPromptView.swift', 'w') as f:
        f.write(content)
        
    print("Success")
except Exception as e:
    print(f"Error: {e}")

