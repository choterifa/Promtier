import SwiftUI

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var showingExportSheet = false
    @Published var showingImportSheet = false
    @Published var showingResetAlert = false
    @Published var showingPremiumUpsell = false
    @Published var hoveredTab: Int? = nil
    
    let tabs: [(title: LocalizedStringKey, icon: String)] = [
        (title: "appearance_tab", icon: "paintbrush.fill"),
        (title: "general_tab", icon: "gearshape.fill"),
        (title: "shortcuts_tab", icon: "keyboard.fill"),
        (title: "ai_tab", icon: "sparkles"),
        (title: "snippets_tab", icon: "text.quote"),
        (title: "data_tab", icon: "externaldrive.fill"),
        (title: "support_tab", icon: "questionmark.circle.fill"),
        (title: "trash_tab", icon: "trash.fill")
    ]
}
