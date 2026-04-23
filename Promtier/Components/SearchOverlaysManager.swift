import SwiftUI

struct SearchOverlaysManager: View {
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var promptService: PromptService
    
    @Binding var fillingVariablesFor: Prompt?
    @Binding var showParticles: Bool
    @Binding var currentGhostTip: GhostTip?
    
    var selectedPromptCategoryColor: Color
    var isGhostTipSuppressedByClipboard: Bool
    var onCopyFinalPrompt: (String, Prompt) -> Void
    var onCancelVariableFill: () -> Void
    var onClearGhostTip: () -> Void
    
    var body: some View {
        ZStack {
            // Overlay de Variables Dinámicas
            if let prompt = fillingVariablesFor {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                onCancelVariableFill()
                            }
                        
                        VariableFillView(prompt: prompt, onCopy: { finalContent in
                            onCopyFinalPrompt(finalContent, prompt)
                        }, onCancel: {
                            onCancelVariableFill()
                        })
                        .frame(maxHeight: geo.size.height * 0.80)
                        .transition(.scale.combined(with: .opacity))
                        .environmentObject(preferences)
                    }
                }
                .zIndex(100)
                .transition(.opacity)
            }
            
            // Guía de Redimensionado Global
            if preferences.isResizingVisible {
                ResizingGuideView()
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Efectos Visuales
            if showParticles {
                ParticleSystemView(accentColor: .blue)
                    .allowsHitTesting(false)
                    .zIndex(300)
            }
            
            // Overlay de Ghost Tips
            if let tip = currentGhostTip, 
               preferences.ghostTipsEnabled && 
               menuBarManager.activeViewState == .main && 
               menuBarManager.suggestedClipboardContent == nil && 
               !isGhostTipSuppressedByClipboard {
                VStack {
                    Spacer()
                    GhostTipView(tip: tip, highlightColor: selectedPromptCategoryColor) {
                        onClearGhostTip()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
                .padding(.bottom, 24)
                .zIndex(500)
            }
        }
    }
}
