import SwiftUI

struct AIAssistantBar: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Binding var content: String
    @State private var showingMagicTip = false
    @State private var showingMagicTipText = ""
    
    let options = [
        (title: "ai_enhance", icon: "magicmouse.fill", color: Color.blue),
        (title: "ai_professional", icon: "briefcase.fill", color: Color.secondary),
        (title: "ai_concise", icon: "scissors", color: Color.orange),
        (title: "ai_creative", icon: "sparkles", color: Color.purple),
        (title: "ai_fix", icon: "checkmark.shield.fill", color: Color.green)
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.multicolor)
                    Text("apple_intelligence_header".localized(for: preferences.language))
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                
                Spacer()
                
                if showingMagicTip {
                    Text(showingMagicTipText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.title) { option in
                        Button(action: {
                            if option.title == "ai_enhance" {
                                enhancePrompt()
                                showingMagicTipText = "ai_tip_applied".localized(for: preferences.language)
                            } else {
                                // Trigger Apple Intelligence Panel
                                NotificationCenter.default.post(name: NSNotification.Name("TriggerAppleIntelligence"), object: nil)
                                showingMagicTipText = String(format: "ai_tip_writing_tools".localized(for: preferences.language), option.title.localized(for: preferences.language))
                            }
                            
                            withAnimation(.spring()) {
                                showingMagicTip = true
                                let haptic = NSHapticFeedbackManager.defaultPerformer
                                haptic.perform(.generic, performanceTime: .now)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showingMagicTip = false }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 11, weight: .bold))
                                Text(option.title.localized(for: preferences.language))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(option.color.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(option.color.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(option.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
    
    private func enhancePrompt() {
        guard !content.isEmpty else { return }
        
        let enhancement = "\n\n---\n[Optimización sugerida: Estructura este prompt con instrucciones claras, utiliza un tono directo y define el rol del asistente.]"
        
        if !content.contains("[Optimización sugerida") {
            content += enhancement
        }
    }
}
