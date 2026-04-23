import SwiftUI

struct ResizingGuideView: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.1).edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 70, height: 70)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 28, weight: .bold)).foregroundColor(.blue)
                }
                VStack(spacing: 6) {
                    Text(NSLocalizedString("target_size", comment: "")).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).tracking(1.5).textCase(.uppercase)
                    HStack(spacing: 25) {
                        VStack {
                            Text("\(Int(preferences.previewWidth))").font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("width", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Divider().frame(height: 35)
                        VStack {
                            Text("\(Int(preferences.previewHeight))").font(.system(size: 24, weight: .bold, design: .monospaced))
                            Text(NSLocalizedString("height", comment: "")).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                Text(NSLocalizedString("release_to_apply", comment: "")).font(.system(size: 10, weight: .medium)).foregroundColor(.blue.opacity(0.7)).padding(.horizontal, 12).padding(.vertical, 4).background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            .padding(32).background(RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial).shadow(color: .black.opacity(0.25), radius: 25, y: 12))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.primary.opacity(0.1), lineWidth: 1))
        }
    }
}
