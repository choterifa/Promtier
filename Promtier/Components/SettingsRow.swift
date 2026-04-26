import SwiftUI

struct SettingsRow<Content: View>: View {
    let label: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let icon: String?
    let iconColor: Color?
    let content: Content
    
    @EnvironmentObject var preferences: PreferencesManager
    
    init(_ label: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, icon: String? = nil, iconColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                labelAndIcon
                
                Spacer(minLength: 16)
                
                // El contenido (Picker, Toggle, etc)
                content
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var labelAndIcon: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18 * preferences.fontSize.scale))
                    .foregroundColor(iconColor ?? .blue)
                    .frame(width: 28 * preferences.fontSize.scale)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14 * preferences.fontSize.scale, weight: .medium))
                    .multilineTextAlignment(.leading)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12 * preferences.fontSize.scale))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}