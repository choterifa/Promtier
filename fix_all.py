import re
import os

# 1. Limpiar PromptTagsEditorView de definiciones duplicadas
path_tags = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptTagsEditorView.swift"
with open(path_tags, "r") as f:
    tags_content = f.read()
# Cortamos justo antes del helper duplicado
tags_content = tags_content.split("// FlowLayout helper")[0]
with open(path_tags, "w") as f:
    f.write(tags_content)

# 2. Reemplazar visualmente las secciones en la "God View"
path_view = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path_view, "r") as f:
    text = f.read()

# Reemplazo de TAGS
tags_old = r'VStack\(alignment: \.leading, spacing: 12\) \{\s*HStack\(spacing: 8\) \{\s*Image\(systemName: "tag\.fill"\).*?\.background\(RoundedRectangle\(cornerRadius: 12\)\.fill\(Color\.primary\.opacity\(0\.02\)\)\)\s*\}'
tags_new = """PromptTagsEditorView(
                        tags: $tags,
                        newTag: $newTag,
                        showingTagEditor: $showingTagEditor,
                        preferences: preferences
                    )"""
text = re.sub(tags_old, tags_new, text, flags=re.DOTALL)

with open(path_view, "w") as f:
    f.write(text)
