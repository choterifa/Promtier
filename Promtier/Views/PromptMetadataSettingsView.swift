import SwiftUI

struct PromptIconPickerButton: View {
    @Binding var selectedIcon: String?
    @Binding var showingIconPicker: Bool

    let fallbackIconName: String
    let themeColor: Color
    let currentCategoryColor: Color

    var body: some View {
        Button(action: { showingIconPicker.toggle() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: selectedIcon ?? fallbackIconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(themeColor)
            }
        }
        .buttonStyle(.plain)
        .help("Change icon")
        .popover(isPresented: $showingIconPicker, arrowEdge: .trailing) {
            IconPickerView(selectedIcon: $selectedIcon, color: currentCategoryColor)
        }
    }
}

struct PromptMetadataSettingsView: View {
    @Binding var selectedFolder: String?
    @Binding var isFavorite: Bool
    @Binding var selectedIcon: String?
    @Binding var showingIconPicker: Bool

    let fallbackIconName: String
    let themeColor: Color
    let currentCategoryColor: Color
    var showsIconButton: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if showsIconButton {
                PromptIconPickerButton(
                    selectedIcon: $selectedIcon,
                    showingIconPicker: $showingIconPicker,
                    fallbackIconName: fallbackIconName,
                    themeColor: themeColor,
                    currentCategoryColor: currentCategoryColor
                )
            }

            CategoryPillPicker(selectedCategory: $selectedFolder, isFavorite: $isFavorite, showLabel: false)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}