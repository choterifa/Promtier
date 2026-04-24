with open('Promtier/Views/OmniSearchView.swift', 'r') as f:
    content = f.read()

content = content.replace(') { [weak self] results in\n            guard let self = self else { return }', ') { results in')
content = content.replace('self.makeSearchResultItem', 'makeSearchResultItem')
content = content.replace('self.filteredResults', 'filteredResults')
content = content.replace('self.visibleResultIndices', 'visibleResultIndices')
content = content.replace('self.selectedIndex', 'selectedIndex')

with open('Promtier/Views/OmniSearchView.swift', 'w') as f:
    f.write(content)
