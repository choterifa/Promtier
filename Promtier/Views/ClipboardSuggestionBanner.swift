import SwiftUI

struct ClipboardSuggestionBanner: View {
    let content: String
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    
    @State private var progress: CGFloat = 1.0
    @State private var isHovered: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .blur(radius: isHovered ? 8 : 4)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                    .shadow(color: preferences.isHaloEffectEnabled ? .blue.opacity(0.5) : .clear, radius: isHovered ? 8 : 5)
            }
            .scaleEffect(isHovered ? 1.0 : 1.0)
            VStack(alignment: .leading, spacing: 2) {
                Text("clipboard_banner_title".localized(for: preferences.language)).font(.system(size: 12, weight: .bold)).foregroundColor(.primary.opacity(0.9))
                Text(content).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
            Button(action: {
                let newPrompt = Prompt(title: "", content: content, folder: nil, tags: [])
                DraftService.shared.saveDraft(prompt: newPrompt, isEditing: false)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    menuBarManager.activeViewState = .newPrompt
                    menuBarManager.isModalActive = true
                    menuBarManager.suggestedClipboardContent = nil
                }
                HapticService.shared.playLight()
            }) {
                Text("clipboard_banner_action".localized(for: preferences.language))
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            if preferences.isHaloEffectEnabled {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: .blue.opacity(0.4), radius: isHovered ? 10 : 6, y: isHovered ? 4 : 2)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            }
                        }
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            Button(action: { withAnimation(.easeOut(duration: 0.25)) { menuBarManager.suggestedClipboardContent = nil } }) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .black)).foregroundColor(.secondary.opacity(0.5)).frame(width: 26, height: 26).background(Circle().fill(Color.primary.opacity(0.04)))
            }.buttonStyle(.plain)
        }.padding(12)
        .frame(maxWidth: preferences.windowWidth * 0.65)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                
                if preferences.isHaloEffectEnabled {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.03), .clear, .blue.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.15), radius: isHovered ? 25 : 20, y: isHovered ? 12 : 10)
        )
        .overlay(
            ZStack(alignment: .bottom) {
                // Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .primary.opacity(isHovered ? 0.25 : 0.12),
                                .primary.opacity(0.05),
                                .primary.opacity(isHovered ? 0.2 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Progress Bar (Timer)
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .blue.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 2)
                        .cornerRadius(1)
                }
                .frame(height: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
                .opacity(0.8)
            }
        )
        .scaleEffect(isHovered ? 1.008 : 1.0)
        .offset(y: isHovered ? -1 : 0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.3)) {
                progress = 0.0
            }
        }
        .padding(.bottom, 8)
    }
}
