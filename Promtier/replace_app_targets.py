import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

pattern = r'// Contextual Awareness \(App Association\)\s+VStack\(alignment: \.leading, spacing: 12\) \{\s+HStack\(spacing: 8\) \{\s+Image\(systemName: "sparkles"\).*?\.overlay\(\s*RoundedRectangle\(cornerRadius: 16\)\s*\.stroke.*?lineWidth: 1\)\s*\)\s*\)\s*\}'

replacement = """// Contextual Awareness (App Association)
                PromptAppTargetsView(
                    targetAppBundleIDs: $targetAppBundleIDs,
                    showingAppPicker: $showingAppPicker,
                    themeColor: themeColor,
                    currentCategoryColor: currentCategoryColor,
                    preferences: preferences,
                    promptService: promptService,
                    showingSmartHelp: $showingSmartHelp,
                    onBrowse: { selectApplication() }
                )"""

new_text = re.sub(pattern, replacement, text, flags=re.DOTALL)
with open(path, "w") as f:
    f.write(new_text)
