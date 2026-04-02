import sys

with open("Promtier/Views/NewPromptView.swift", "r") as f:
    lines = f.readlines()

new_lines = []
skip_debounce = False
i = 0
while i < len(lines):
    line = lines[i]
    if "autoSaveWorkItem" in line:
        i += 1
        continue

    if "debounceAutoSave(" in line:
        if "private func debounceAutoSave()" in line:
            skip_debounce = True
            i += 1
            continue
        elif "debounceAutoSave" in line: # maybe a call
            i += 1
            continue

    if skip_debounce:
        if line.startswith("    }") and i + 2 < len(lines) and "dismissSnippetsOverlay" in lines[i+2]:
            skip_debounce = False
        i += 1
        continue
        
    if "private func savePrompt(closeAfter: Bool = true, isAutoSave: Bool = false) {" in line:
        new_lines.append(line.replace(", isAutoSave: Bool = false", ""))
        i += 1
        continue
    
    if "savePrompt(closeAfter: true, isAutoSave: false)" in line          new_lines.append(line.replace(", isAutoSave: false", ""))
        i += 1
        continue

    if line.strip() == "if !isAutoSave {":
        if "isSaving = true" in lines[i+1]:
            new_lines.append(lines[i+1])
            i += 3
            continue

    if "if isAutoSave {" in line:
        if "self.originalPrompt = new" in lines[i+1]:
            i += 3
            continue

    if "if preferences.isPremiumActive && !isAutoSave {" in line:
        new_lines.append(line.replace(" && !isAutoSave", ""))
        i += 1
        continue

    if "if preferences.isPremiumActive && preferences.visualEffectsEnabled && !isAutoSave {" in line:
        new_lines.append(line.replace(" && !isAutoSave", ""))
        i += 1
        continue

    if "if isNewPrompt && !isAutoSave {" in line:
        new_lines.append(line.replace(" && !isAutoSave", ""))
        i += 1
        continue

    new_lines.append(line)
    i += 1

with open("Promtier/Views/NewPromptView.swift", "w") as f:
    f.writelines(new_lines)
