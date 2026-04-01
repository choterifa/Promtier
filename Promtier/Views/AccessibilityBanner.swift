import SwiftUI

struct AccessibilityBanner: View {
    @EnvironmentObject var preferences: PreferencesManager
    @State private var isVisible = true
    
    // Rastrea si el banner ya se mostró al menos una vez en esta sesión de la app
    static var hasShownThisSession = false

    var body: some View {
        if isVisible && !Self.hasShownThisSession {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill").foregroundColor(.orange).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("accessibility_permissions", comment: "")).font(.system(size: 12, weight: .bold))
                    Text(NSLocalizedString("accessibility_required_for_paste", comment: "")).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(NSLocalizedString("accessibility_configure", comment: "")) { ShortcutManager.shared.checkAccessibilityPermissions(forceDialog: true) }.buttonStyle(.bordered).controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))
            .overlay(Rectangle().frame(height: 1).foregroundColor(.orange.opacity(0.15)), alignment: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                Self.hasShownThisSession = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.easeInOut) {
                        isVisible = false
                    }
                }
            }
        }
    }
}
