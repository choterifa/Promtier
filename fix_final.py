import re

# 1. Añadir import UniformTypeIdentifiers a PromptImageShowcaseView.swift
path_img = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/PromptImageShowcaseView.swift"
with open(path_img, "r") as f:
    img_content = f.read()
if "import UniformTypeIdentifiers" not in img_content:
    img_content = img_content.replace("import SwiftUI", "import SwiftUI\nimport UniformTypeIdentifiers")
with open(path_img, "w") as f:
    f.write(img_content)

# 2. Reemplazar visualmente la sección de Imágenes en NewPromptView.swift
path_view = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/Views/NewPromptView.swift"
with open(path_view, "r") as f:
    text = f.read()

# Reemplazo de IMAGENES
img_old = r'// Prompt Results \(Moved here per user request\)\s*PromptImageShowcaseView\(.*?\)'
img_new = """// Prompt Results (Extracted Component)
                PromptImageShowcaseView(
                    showcaseImages: $showcaseImages,
                    isDragging: $isDragging,
                    draggedImageIndex: $draggedImageIndex,
                    showingFullScreenImage: $showingFullScreenImage,
                    selectedImageIndex: $selectedImageIndex,
                    branchMessage: $branchMessage,
                    preferences: preferences
                )"""
text = re.sub(img_old, img_new, text, flags=re.DOTALL)

# Reemplazo de APP ASSOCIATION
app_old = r'// Contextual Awareness \(App Association\)\s*PromptAppTargetsView\(.*?\)'
app_new = """// Contextual Awareness (App Association)
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
text = re.sub(app_old, app_new, text, flags=re.DOTALL)

with open(path_view, "w") as f:
    f.write(text)
