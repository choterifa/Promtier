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
    
    @State private var useVerticalLayout = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if useVerticalLayout {
                VStack(alignment: .leading, spacing: 12) {
                    labelAndIcon
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    labelAndIcon
                    Spacer(minLength: 16)
                    content
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateLayout(width: proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, width in
                        updateLayout(width: width)
                    }
            }
        )
        .contentShape(Rectangle())
    }
    
    private func updateLayout(width: CGFloat) {
        let threshold: CGFloat = 480 // Aumentado para dar más margen al texto
        if width < threshold && !useVerticalLayout {
            useVerticalLayout = true
        } else if width >= threshold && useVerticalLayout {
            useVerticalLayout = false
        }
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