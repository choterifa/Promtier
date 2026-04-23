import SwiftUI

struct PromptResultsSectionView: View {
    @Binding var showcaseImages: [Data]
    @Binding var mediaState: PromptMediaState
    @Binding var branchMessage: String?

    let preferences: PreferencesManager
    let themeColor: Color

    var body: some View {
        PromptImageShowcaseView(
            showcaseImages: $showcaseImages,
            mediaState: $mediaState,
            branchMessage: $branchMessage,
            preferences: preferences,
            themeColor: themeColor
        )
        .padding(.horizontal, 4)
    }
}
