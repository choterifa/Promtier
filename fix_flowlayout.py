import os

# 1. Quitar FlowLayout de PromptTagsEditorView.swift (ya existe en SharedAppPicker)
path_tags = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptTagsEditorView.swift"
with open(path_tags, "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "struct FlowLayout: Layout {" in line:
        skip = True
    if not skip:
        new_lines.append(line)
    if skip and line.strip() == "}":
        # Solo dejamos de skipear si es el cierre de struct final (heurística simple pero efectiva aquí)
        # En este archivo el Layout termina en la última línea útil
        pass

# Para ser más precisos, simplemente truncamos el archivo antes de la definición duplicada
with open(path_tags, "w") as f:
    for line in new_lines:
        if "// FlowLayout helper" in line: break
        f.write(line)

# 2. Reemplazar el bloque de Tags en NewPromptView.swift
path_view = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path_view, "r") as f:
    text = f.read()

# Patrón para la sección de Tags (VStack con tag.fill)
tags_pattern = r'VStack\(alignment: \.leading, spacing: 12\) \{\s*HStack\(spacing: 8\) \{\s*Image\(systemName: "tag\.fill"\).*?\.background\(RoundedRectangle\(cornerRadius: 12\)\.fill\(Color\.primary\.opacity\(0\.02\)\)\)\s*\}'

replacement_tags = """PromptTagsEditorView(
                        tags: $tags,
                        newTag: $newTag,
                        showingTagEditor: $showingTagEditor,
                        preferences: preferences
                    )"""

text = re.sub(tags_pattern, replacement_tags, text, flags=re.DOTALL)

with open(path_view, "w") as f:
    f.write(text)
