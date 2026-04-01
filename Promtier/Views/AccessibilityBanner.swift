import SwiftUI

struct AccessibilityBanner: View {
    @EnvironmentObject var preferences: PreferencesManager
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundColor(.orange).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("accessibility_permissions", comment: "")).font(.system(size: 12, weight: .bold))
                Text(NSLocalizedString("accessibility_required_for_paste", comment: "")).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(NSLocalizedString("configure", comment: "")) { ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true) }.buttonStyle(.bordered).controlSize(.small)
            }
        }.padding(.horizontal, 16).padding(.vertical, 10).background(Color.orange.opacity(0.08)).overlay(Rectangle().frame(height: 1).foregroundColor(.orange.opacity(0.15)), alignment: .bottom)
    }
}
