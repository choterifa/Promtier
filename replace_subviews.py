import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path, "r") as f:
    text = f.read()

# Replace Tags section
tags_pattern = r"HStack\(spacing: 8\) \{\n\s*Image\(systemName: \"tag\.fill\"\).*?\n\s*\}\n\s*\}\n\s*\}\n\s*\}\n\s*\}\n\s*\.padding\(12\)\n\s*\.background\(RoundedRectangle\(cornerRadius: 12\)\.fill\(Color\.primary\.opacity\(0\.02\)\)\)\n\s*\}"

replacement_tags = """PromptTagsEditorView(
                        tags: $tags,
                        newTag: $newTag,
                        showingTagEditor: $showingTagEditor,
                        preferences: preferences
                    )"""

# In the actual file it's part of a VStack. Let's do a more precise replacement or just find the block manually.
