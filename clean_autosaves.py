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

    if "private func debounceAutoSave()" in line:
        skip_debounce = True
        i += 1
        continue

    if skip_debounce:
        # End of 'debounceAutoSave' function is marked by the line "    }" just before
        # "    private func dismissSnippetsOverlay()" or similar.
        # Actually it's simple: we can just check if we reach a line that defines another private func
        if line.startswith("    private func dismissSnippetsOverlay() {"):
            skip_debounce = False
            # Don't skip this line, we want to append it.
            new_lines.append(line)
        i += 1
        continue

    # Replace usages
    if "private func savePrompt(closeAfter: Bool = true, isAutoSave: Bool = false) {" in line:
        new_lines.append(line.replace(", isAutoSave: Bool = false", ""))
        i += 1
        continue

    if "savePrompt(closeAfter: true, isAutoSave: false)" in line:
        new_lines.append(line.replace(", isAutoSave: false", ""))
        i += 1
        continue

    if "savePrompt(closeAfter: false, isAutoSave: true)" in line:
        # This one inside debounceAutoSave shouldn't normally be hit if skip_debounce is correct, but just in case
        i += 1
        continue

    # Remove the !isAutoSave guard block at the beginning of savePrompt
    if line.strip() == "if !isAutoSave {":
        if "isSaving = true" in lines[i+1]:
            new_lines.append("        isSaving = true\n")
            i += 3
            continue

    # Remove the `isAutoSave` condition near the end for UI updates
    if "if isAutoSave {" in line.strip() and "DispatchQueue.main.async" in lines[i+1] and "originalPrompt = new" in lines[i+1]:
        i += 4
        continue

    # Remove conditionals
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
print("done")
