import SwiftUI

struct EditorToolbar: View {
    @EnvironmentObject var preferences: PreferencesManager
    let color: Color
    let editorID: String
    var vertical: Bool = false

    @Binding var content: String
    @Binding var selectedRange: NSRange?

    // AI Actions
    var isAIGenerating: Bool
    var onAIAction: (AIAction) -> Void
    var aiEnabled: Bool

    // Snippets & Variables
    var onShowVariables: () -> Void
    var onShowSnippets: () -> Void
    var onShowChains: () -> Void

    // Zen Mode & Other
    var onZenMode: () -> Void
    var onFloatingMode: (() -> Void)? = nil
    
    // Magic
    var isAutocompleting: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil

    init(color: Color, editorID: String, vertical: Bool = false,
         content: Binding<String>, selectedRange: Binding<NSRange?>,
         isAIGenerating: Bool, onAIAction: @escaping (AIAction) -> Void, aiEnabled: Bool,
         onShowVariables: @escaping () -> Void, onShowSnippets: @escaping () -> Void,
         onShowChains: @escaping () -> Void, onZenMode: @escaping () -> Void,
         onFloatingMode: (() -> Void)? = nil,
         isAutocompleting: Bool = false, onMagicAutocomplete: (() -> Void)? = nil) {
        self.color = color
        self.editorID = editorID
        self.vertical = vertical
        self._content = content
        self._selectedRange = selectedRange
        self.isAIGenerating = isAIGenerating
        self.onAIAction = onAIAction
        self.aiEnabled = aiEnabled
        self.onShowVariables = onShowVariables
        self.onShowSnippets = onShowSnippets
        self.onShowChains = onShowChains
        self.onZenMode = onZenMode
        self.onFloatingMode = onFloatingMode
        self.isAutocompleting = isAutocompleting
        self.onMagicAutocomplete = onMagicAutocomplete
    }

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 8) {
                    buttons
                }
            } else {
                HStack(spacing: 8) {
                    buttons
                }
            }
        }
        .padding(vertical ? 6 : 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private var buttons: some View {
        Menu {
            Button(action: { send(.bold) }) {
                Label("Bold", systemImage: "bold")
            }
            Button(action: { send(.italic) }) {
                Label("Italic", systemImage: "italic")
            }
            Button(action: { send(.strikethrough) }) {
                Label("Strikethrough", systemImage: "strikethrough")
            }
            Button(action: { send(.inlineCode) }) {
                Label("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Divider()
            Button(action: { send(.bulletList) }) {
                Label("Bullet List", systemImage: "list.bullet")
            }
            Button(action: { send(.numberedList) }) {
                Label("Numbered List", systemImage: "list.number")
            }
            Divider()
            Button(action: { send(.indent) }) {
                Label("Indent Right", systemImage: "increase.indent")
            }
            Button(action: { send(.outdent) }) {
                Label("Indent Left", systemImage: "decrease.indent")
            }
        } label: {
            toolbarButton(icon: "textformat", isSpecial: false)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Markdown Formatting")
        
        if aiEnabled && onMagicAutocomplete != nil {
            Button(action: { onMagicAutocomplete?() }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(isAutocompleting ? 0.3 : 0.15))
                        .frame(width: 28, height: 28)
                    
                    if isAutocompleting {
                        ProgressView().controlSize(.small).scaleEffect(0.5)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.purple)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("AI Magic: Autocomplete or Improve (Cmd+J)")
        }

        if aiEnabled {
            Menu {
                Button(action: { onAIAction(.enhance) }) {
                    Label("ai_action_enhance".localized(for: preferences.language), systemImage: "sparkles")
                }
                Button(action: { onAIAction(.fix) }) {
                    Label("ai_action_fix".localized(for: preferences.language), systemImage: "checkmark.bubble")
                }
                Button(action: { onAIAction(.concise) }) {
                    Label("ai_action_concise".localized(for: preferences.language), systemImage: "text.alignleft")
                }
                Divider()
                Button(action: { onAIAction(.instruct) }) {
                    Label("ai_action_instruct".localized(for: preferences.language), systemImage: "wand.and.stars.inverse")
                }
            } label: {
                toolbarButton(icon: "sparkles", isSpecial: true, active: isAIGenerating)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }

        Button(action: onShowVariables) {
            toolbarButton(icon: "curlybraces")
        }
        .buttonStyle(.plain)
        .help("Insert Variable")

        Button(action: onShowSnippets) {
            toolbarButton(text: "/")
        }
        .buttonStyle(.plain)
        .help("Insert Snippet")

        Button(action: onShowChains) {
            toolbarButton(icon: "link.badge.plus")
        }
        .buttonStyle(.plain)
        .help("Chain Another Prompt")

        if let onFloating = onFloatingMode {
            Button(action: onFloating) {
                toolbarButton(icon: "pip.enter")
            }
            .buttonStyle(.plain)
            .help("Floating Zen Mode")
        }

        Button(action: onZenMode) {
            toolbarButton(icon: "arrow.up.left.and.arrow.down.right")
        }
        .buttonStyle(.plain)
        .help("Zen Mode")
    }

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? color : .blue
    }

    private var activeColor: Color {
        preferences.isHaloEffectEnabled ? .purple : .blue
    }

    @ViewBuilder
    private func toolbarButton(icon: String? = nil, text: String? = nil, isSpecial: Bool = false, active: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(active ? activeColor.opacity(0.2) : (isSpecial ? themeColor.opacity(0.12) : Color.primary.opacity(0.04)))
                .frame(width: 28, height: 28)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(active ? activeColor : themeColor)
            } else if let text = text {
                Text(text)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(themeColor)
            }
        }
        .scaleEffect(active ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
    }

    private func send(_ action: PromtierEditorCommandAction) {
        PromtierEditorCommandCenter.post(action, to: editorID)
        HapticService.shared.playLight()
    }
}
