import SwiftUI

struct GlossaryRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized(for: preferences.language))
                    .font(.system(size: 13 * preferences.fontSize.scale, weight: .bold))
                Text(description.localized(for: preferences.language))
                    .font(.system(size: 11 * preferences.fontSize.scale))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}