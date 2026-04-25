import re

with open('Promtier/ViewModels/FolderManagerViewModel.swift', 'r') as f:
    content = f.read()

content = content.replace(', useFallback: true', '')

with open('Promtier/ViewModels/FolderManagerViewModel.swift', 'w') as f:
    f.write(content)

with open('Promtier/Core/Protocols/AIServiceProtocol.swift', 'r') as f:
    content = f.read()

content = content.replace(', useFallback: Bool', '')

with open('Promtier/Core/Protocols/AIServiceProtocol.swift', 'w') as f:
    f.write(content)

with open('Promtier/ViewModels/NewPromptViewModel.swift', 'r') as f:
    content = f.read()

content = re.sub(r'^\s*AIServiceManager\.shared\.onFallbackOccurred.*?\n(?:.*\n)?', '', content, flags=re.MULTILINE)

with open('Promtier/ViewModels/NewPromptViewModel.swift', 'w') as f:
    f.write(content)

