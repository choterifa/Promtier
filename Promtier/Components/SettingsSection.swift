import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 14 * preferences.fontSize.scale, weight: .bold))
                Text(title)
                    .font(.system(size: 11 * preferences.fontSize.scale, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .textCase(.uppercase)
            }
            
            VStack(spacing: 1) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}