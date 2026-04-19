import SwiftUI

struct PromptMetadataSettingsView: View {
    @Binding var selectedFolder: String?
    @Binding var isFavorite: Bool
    @Binding var selectedIcon: String?
    @Binding var showingIconPicker: Bool

    let fallbackIconName: String
    let themeColor: Color
    let currentCategoryColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { showingIconPicker.toggle() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColor.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: selectedIcon ?? fallbackIconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeColor)
                }
            }
            .buttonStyle(.plain)
            .help("Change icon")
            .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
                IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
            }

            CategoryPillPicker(selectedCategory: $selectedFolder, isFavorite: $isFavorite, showLabel: false)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}