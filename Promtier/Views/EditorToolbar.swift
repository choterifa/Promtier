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
    var onStopAI: (() -> Void)? = nil

    // Snippets & Variables
    var onShowVariables: () -> Void
    var onShowSnippets: () -> Void
    @Binding var showingPromptChainPicker: Bool
    var chainPopoverContent: (() -> AnyView)?

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
         showingPromptChainPicker: Binding<Bool>, chainPopoverContent: (() -> AnyView)? = nil, onZenMode: @escaping () -> Void,
         onFloatingMode: (() -> Void)? = nil,
         isAutocompleting: Bool = false, onMagicAutocomplete: (() -> Void)? = nil,
         onStopAI: (() -> Void)? = nil) {
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
        self._showingPromptChainPicker = showingPromptChainPicker
        self.chainPopoverContent = chainPopoverContent
        self.onZenMode = onZenMode
        self.onFloatingMode = onFloatingMode
        self.isAutocompleting = isAutocompleting
        self.onMagicAutocomplete = onMagicAutocomplete
        self.onStopAI = onStopAI
    }

    @State private var isMagicHovered: Bool = false
    @State private var magicRotationPhase: Double = 0
    
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
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                magicRotationPhase = 360
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
                if isAutocompleting {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.04))
                            .frame(width: 28, height: 28)
                        ProgressView().controlSize(.small).scaleEffect(0.5)
                    }
                } else {
                    toolbarButton(icon: "wand.and.stars", isSpecial: true, active: isMagicHovered)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isMagicHovered = hovering
                }
            }
            .help("AI Magic: Autocomplete or Improve (Cmd+J)")
        }

        if aiEnabled {
            Button(action: { onAIAction(.translate) }) {
                toolbarButton(icon: "globe", isSpecial: true, active: false)
            }
            .buttonStyle(.plain)
            .help("ai_action_translate".localized(for: preferences.language))

            Menu {
                Button(action: { onAIAction(.enhance) }) {
                    Label("ai_action_enhance".localized(for: preferences.language), systemImage: "pencil.and.outline")
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
                toolbarButton(icon: "pencil.and.outline", isSpecial: false, active: isAIGenerating)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)

            if isAIGenerating, let onStopAI {
                Button(action: onStopAI) {
                    toolbarButton(icon: "stop.fill", isSpecial: true, active: true)
                }
                .buttonStyle(.plain)
                .help("Stop AI")
            }
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

        Button(action: { showingPromptChainPicker.toggle() }) {
            toolbarButton(icon: "link.badge.plus")
        }
        .buttonStyle(.plain)
        .help("Chain Another Prompt")
        .popover(isPresented: $showingPromptChainPicker, arrowEdge: .leading) {
            if let content = chainPopoverContent {
                content()
            }
        }

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
        ToolbarButtonView(
            color: color,
            themeColor: themeColor,
            activeColor: activeColor,
            magicRotationPhase: magicRotationPhase,
            icon: icon,
            text: text,
            isSpecial: isSpecial,
            active: active
        )
    }

    private func send(_ action: PromtierEditorCommandAction) {
        PromtierEditorCommandCenter.post(action, to: editorID)
        HapticService.shared.playLight()
    }
}

struct ToolbarButtonView: View {
    let color: Color
    let themeColor: Color
    let activeColor: Color
    let magicRotationPhase: Double
    let icon: String?
    let text: String?
    let isSpecial: Bool
    let active: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSpecial && active 
                    ? color.opacity(0.35) 
                    : (isSpecial ? color.opacity(isHovered ? 0.3 : 0.22) : (active ? activeColor.opacity(0.25) : Color.primary.opacity(isHovered ? 0.08 : 0.04))))
                .frame(width: 31, height: 31)
                .shadow(color: isSpecial && active ? color.opacity(0.7) : .clear, radius: isSpecial && active ? 10 : 0)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(isSpecial && active ? color : (isSpecial ? color.opacity(0.85) : (active ? activeColor : themeColor)))
            } else if let text = text {
                Text(text)
                    .font(.system(size: 14.5, weight: .black, design: .monospaced))
                    .foregroundColor(themeColor)
            }
        }
        .overlay(
            Group {
                if isSpecial && active {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [color, color.opacity(0.7), color.opacity(0.4), color.opacity(0.8), color, color.opacity(0.7), color.opacity(0.4), color.opacity(0.8)],
                                startPoint: UnitPoint(x: (magicRotationPhase / 360.0) - 1.0, y: 0),
                                endPoint: UnitPoint(x: (magicRotationPhase / 360.0), y: 1)
                            ),
                            lineWidth: 1.2
                        )
                }
            }
        )
        .scaleEffect(active ? 1.1 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
    }
}
