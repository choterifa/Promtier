import SwiftUI

struct PromptPickerPopover: View {
    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    let excludePromptId: UUID?
    let onSelect: (Prompt) -> Void
    
    @State private var searchQuery: String = ""
    
    private var filteredPrompts: [Prompt] {
        let all = promptService.prompts
        let filtered = all.filter { prompt in
            if let excludeId = excludePromptId, prompt.id == excludeId { return false }
            if searchQuery.isEmpty { return true }
            return prompt.title.localizedCaseInsensitiveContains(searchQuery) ||
                   (prompt.folder?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
        return filtered.sorted(by: { $0.title < $1.title })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Buscador
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("search_prompts_placeholder".localized(for: preferences.language), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(10)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding(12)
            
            Divider()
            
            // Lista
            ScrollView {
                VStack(spacing: 4) {
                    if filteredPrompts.isEmpty {
                        Text("no_results".localized(for: preferences.language))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        ForEach(filteredPrompts) { prompt in
                            promptRow(for: prompt)
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
    }
    
    @ViewBuilder
    private func promptRow(for prompt: Prompt) -> some View {
        Button(action: { onSelect(prompt) }) {
            HStack(spacing: 10) {
                // Icono
                ZStack {
                    let color = prompt.folder.flatMap { PredefinedCategory.fromString($0)?.color } ?? .blue
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: prompt.icon ?? prompt.folder.flatMap { PredefinedCategory.fromString($0)?.icon } ?? "doc.text.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(prompt.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if let folder = prompt.folder {
                        Text(folder)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .textCase(.uppercase)
                    }
                }
                
                Spacer()
                
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.blue.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .opacity(0) // Se activa con hover si quisiéramos, pero por ahora simple
        )
    }
}
