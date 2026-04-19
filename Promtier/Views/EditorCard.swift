import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine


struct EditorCard: View {
    private enum Layout {
        static let headerSpacing: CGFloat = 14
        static let headerInnerSpacing: CGFloat = 6
        static let titleFontSize: CGFloat = 22
        static let subtitleFontSize: CGFloat = 13
        static let editorCornerRadius: CGFloat = 16
        static let editorToolbarVerticalPadding: CGFloat = 8
        static let editorToolbarTrailingPadding: CGFloat = 4
        static let editorTopPadding: CGFloat = 14
        static let editorIdleBorderWidth: CGFloat = 1.5
        static let editorActiveBorderWidth: CGFloat = 2
    }

    @Binding var title: String
    @Binding var content: String
    @Binding var promptDescription: String
    @Binding var isFavorite: Bool
    @Binding var selectedFolder: String?
    @Binding var selectedIcon: String?
    let fallbackIconName: String
    @Binding var showingIconPicker: Bool
    @Binding var showingZenEditor: Bool
    @Binding var zenTarget: NewPromptView.ZenEditorTarget?
    @Binding var showingPremiumFor: String?
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    @Binding var showVariables: Bool
    @Binding var variablesSelectedIndex: Int
    @Binding var triggerVariablesSelection: Bool
    @Binding var triggerAIRequest: String?
    @Binding var isAIActive: Bool
    @Binding var isAIGenerating: Bool
    @Binding var selectedRange: NSRange?
    @Binding var aiResult: AIResult?
    var originalPrompt: Prompt?
    var prompt: Prompt?
    @Binding var branchMessage: String?
    let editorID: String

    let currentCategoryColor: Color
    
    var isAutocompleting: Bool = false
    var isCategorizing: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil
    var onMagicCategorize: (() -> Void)? = nil

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? currentCategoryColor : Color.blue
    }

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager
    
    init(title: Binding<String>, content: Binding<String>, promptDescription: Binding<String>, 
         isFavorite: Binding<Bool>, selectedFolder: Binding<String?>, selectedIcon: Binding<String?>, 
         fallbackIconName: String, showingIconPicker: Binding<Bool>, showingZenEditor: Binding<Bool>, 
         zenTarget: Binding<NewPromptView.ZenEditorTarget?>, showingPremiumFor: Binding<String?>, 
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>, 
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>, 
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>, 
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>, 
         triggerVariablesSelection: Binding<Bool>, triggerAIRequest: Binding<String?>, 
         isAIActive: Binding<Bool>, isAIGenerating: Binding<Bool>, 
         isAutocompleting: Bool = false, isCategorizing: Bool = false, 
         onMagicAutocomplete: (() -> Void)? = nil, onMagicCategorize: (() -> Void)? = nil, 
         selectedRange: Binding<NSRange?>, aiResult: Binding<AIResult?>, 
         originalPrompt: Prompt? = nil, prompt: Prompt? = nil, 
         branchMessage: Binding<String?>, editorID: String, 
         currentCategoryColor: Color) {
        self._title = title
        self._content = content
        self._promptDescription = promptDescription
        self._isFavorite = isFavorite
        self._selectedFolder = selectedFolder
        self._selectedIcon = selectedIcon
        self.fallbackIconName = fallbackIconName
        self._showingIconPicker = showingIconPicker
        self._showingZenEditor = showingZenEditor
        self._zenTarget = zenTarget
        self._showingPremiumFor = showingPremiumFor
        self._insertionRequest = insertionRequest
        self._replaceSnippetRequest = replaceSnippetRequest
        self._showSnippets = showSnippets
        self._snippetSearchQuery = snippetSearchQuery
        self._snippetSelectedIndex = snippetSelectedIndex
        self._triggerSnippetSelection = triggerSnippetSelection
        self._showVariables = showVariables
        self._variablesSelectedIndex = variablesSelectedIndex
        self._triggerVariablesSelection = triggerVariablesSelection
        self._triggerAIRequest = triggerAIRequest
        self._isAIActive = isAIActive
        self._isAIGenerating = isAIGenerating
        self.isAutocompleting = isAutocompleting
        self.isCategorizing = isCategorizing
        self.onMagicAutocomplete = onMagicAutocomplete
        self.onMagicCategorize = onMagicCategorize
        self._selectedRange = selectedRange
        self._aiResult = aiResult
        self.originalPrompt = originalPrompt
        self.prompt = prompt
        self._branchMessage = branchMessage
        self.editorID = editorID
        self.currentCategoryColor = currentCategoryColor
    }

    private var isAIAvailable: Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }
    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var isMagicPulsing = false
    @State private var isMagicHovered = false
    @State private var magicRotationPhase: Double = 0
    @State private var cancellables = Set<AnyCancellable>()
    @State private var plainTextContent: String = ""
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var showingInstructionAlert = false
    @State private var instructionInput = ""
    @State private var isDraggingMagicImage = false
    @State private var isMagicImageProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Layout.headerSpacing) {
                VStack(alignment: .leading, spacing: Layout.headerInnerSpacing) {
                    HStack(alignment: .firstTextBaseline) {
                        PromptIconPickerButton(
                            selectedIcon: $selectedIcon,
                            showingIconPicker: $showingIconPicker,
                            fallbackIconName: fallbackIconName,
                            themeColor: themeColor,
                            currentCategoryColor: currentCategoryColor
                        )

                        TextField("prompt_title_placeholder".localized(for: preferences.language), text: $title, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: Layout.titleFontSize * preferences.fontSize.scale, weight: .bold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // ✨ Botón Mágico: Autocompletar Título
                        if editorID == "main" {
                            MagicImageDropZone(isDraggingImage: $isDraggingMagicImage) { data in
                                extractMagicPrompt(from: data)
                            }
                            .scaleEffect(0.65)
                            .frame(width: 26, height: 26)
                            .padding(.trailing, 2)
                            
                            Button(action: {
                                withAnimation { isMagicPulsing = false }
                                onMagicAutocomplete?()
                            }) {
                                HStack(spacing: 4) {
                                    if isAutocompleting {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.4)
                                            .frame(width: 8, height: 8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 10, weight: .bold))
                                            .frame(width: 12, height: 12)
                                    }
                                    
                                    Text(isAutocompleting ? "STOP" : "MAGIC")
                                        .font(.system(size: 10.5, weight: .heavy))
                                        .frame(width: 42, alignment: .center)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(preferences.isHaloEffectEnabled
                                            ? AnyShapeStyle(LinearGradient(
                                                colors: [currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22), currentCategoryColor.opacity(isMagicHovered ? 0.35 : 0.22)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            : AnyShapeStyle(themeColor.opacity(isMagicHovered ? 0.15 : 0.08)))
                                        .opacity(isMagicPulsing ? 0.5 : 1.0)
                                        .shadow(color: (preferences.isHaloEffectEnabled && isMagicPulsing) ? currentCategoryColor.opacity(0.7) : (preferences.isHaloEffectEnabled && isMagicHovered ? currentCategoryColor.opacity(0.6) : .clear),
                                               radius: isMagicPulsing ? 8 : (isMagicHovered ? 14 : 0))
                                )
                                .foregroundColor(isMagicHovered ? themeColor : themeColor.opacity(0.9))
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            preferences.isHaloEffectEnabled
                                                ? AnyShapeStyle(AngularGradient(
                                                    colors: [currentCategoryColor, currentCategoryColor.opacity(0.1), currentCategoryColor],
                                                    center: .center,
                                                    startAngle: .degrees(magicRotationPhase),
                                                    endAngle: .degrees(magicRotationPhase + 360)
                                                ))
                                                : AnyShapeStyle(themeColor.opacity(0.8)),
                                            lineWidth: isMagicPulsing ? 1.4 : (isMagicHovered ? 1.2 : 0.8)
                                        )
                                        .opacity(isMagicPulsing ? 0.8 : (isMagicHovered ? 1.0 : 0.5))
                                )
                                .scaleEffect(isMagicHovered ? 1.02 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
                                    magicRotationPhase = 360
                                }
                            }
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isMagicHovered = hovering
                                }
                            }
                            .animation(
                                isMagicPulsing
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .spring(response: 0.3, dampingFraction: 0.7),
                                value: isMagicPulsing
                            )
                            .help("Autocomplete content based on title (Cmd+J)")
                            .padding(.top, 2)
                        }
                    }

                    TextField("short_desc_placeholder".localized(for: preferences.language), text: $promptDescription, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: Layout.subtitleFontSize * preferences.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                        .frame(minHeight: 28, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } // Cierre de la cabecera (VStack en 1695)

            // ✅ Editor Principal con Herramientas Inteligentes (Sidebar Layout)
            HStack(alignment: .top, spacing: 0) {
                // El Editor
                HighlightedEditor(
                    text: $content,
                    plainText: $plainTextContent,
                    insertionRequest: $insertionRequest,
                    replaceSnippetRequest: $replaceSnippetRequest,
                    triggerAIRequest: $triggerAIRequest,
                    isAIActive: $isAIActive,
                    editorID: editorID,
                    isFocused: $isEditorFocused,
                    selectedRange: $selectedRange,
                    aiResult: $aiResult,
                    fontSize: 16 * preferences.fontSize.scale,
                    themeColor: NSColor(themeColor),
                    showSnippets: $showSnippets,
                    snippetSearchQuery: $snippetSearchQuery,
                    snippetSelectedIndex: $snippetSelectedIndex,
                    triggerSnippetSelection: $triggerSnippetSelection,
                    showVariables: $showVariables,
                    variablesSelectedIndex: $variablesSelectedIndex,
                    triggerVariablesSelection: $triggerVariablesSelection,
                    isPremium: preferences.isPremiumActive,
                    isHaloEffectEnabled: preferences.isHaloEffectEnabled,
                    isTyping: $isTyping,
                    onPaste: {
                        withAnimation(.spring()) {
                            isMagicPulsing = true
                        }
                        // Auto-dismiss pulse after 7 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                            withAnimation(.easeInOut) {
                                isMagicPulsing = false
                            }
                        }
                    }
                )
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .padding(.trailing, 5) // Espacio sutil de 5px
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)

                // Barra de Herramientas Lateral
                  EditorToolbar(
                    color: currentCategoryColor,
                    editorID: editorID,
                    vertical: true,
                    content: $content,
                    selectedRange: $selectedRange,
                    isAIGenerating: isAIGenerating,
                    onAIAction: { performAIAction($0) },
                    aiEnabled: isAIAvailable,
                    onShowVariables: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showVariables.toggle()
                                variablesSelectedIndex = 0
                            }
                        } else {
                            showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                        }
                    },
                    onShowSnippets: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSnippets.toggle()
                                snippetSearchQuery = ""
                            }
                        } else {
                            showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                        }
                    },
                    showingPromptChainPicker: $showingPromptChainPicker,
                    chainPopoverContent: {
                        AnyView(
                            PromptPickerPopover(excludePromptId: prompt?.id) { selected in
                                insertionRequest = "[[@Prompt:\(selected.title)]]"
                                showingPromptChainPicker = false
                            }
                        )
                    },
                    onZenMode: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingZenEditor = true
                            zenTarget = .main
                        }
                    },
                    onFloatingMode: nil,
                    isAutocompleting: isAutocompleting,
                    onMagicAutocomplete: editorID == "main" ? nil : { onMagicAutocomplete?() },
                    onStopAI: {
                        aiTask?.cancel()
                        isAIGenerating = false
                    }
                )
                .padding(.vertical, Layout.editorToolbarVerticalPadding)
                .padding(.trailing, Layout.editorToolbarTrailingPadding) // Ajustado para dar más espacio al texto
            }
            .background(
                RoundedRectangle(cornerRadius: Layout.editorCornerRadius)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.editorCornerRadius)
                            .stroke(themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isTyping ? Layout.editorActiveBorderWidth : Layout.editorIdleBorderWidth)
                            .shadow(color: preferences.isHaloEffectEnabled ? currentCategoryColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .padding(.top, Layout.editorTopPadding) // Espacio EXTERNO entre descripción y caja del editor
            .animation(.easeInOut(duration: 0.3), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(isTyping ? .spring(response: 0.35, dampingFraction: 0.7) : .easeOut(duration: 1.5), value: isTyping)
            .contentShape(Rectangle()) // <---- CRITICAL: Evita zonas muertas transparentes
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorFocused = true
                }
            }

            PromptMetadataSettingsView(
                selectedFolder: $selectedFolder,
                isFavorite: $isFavorite,
                selectedIcon: $selectedIcon,
                showingIconPicker: $showingIconPicker,
                fallbackIconName: fallbackIconName,
                themeColor: themeColor,
                currentCategoryColor: currentCategoryColor,
                showsIconButton: false
            )

        }
        .alert("Execute Command", isPresented: $showingInstructionAlert) {
            TextField("Instruction (e.g. Translate to French)", text: $instructionInput)
            Button("Cancel", role: .cancel) { }
            Button("Execute") {
                performAIAction(.instruct, instruction: instructionInput)
            }
        } message: {
            Text("Enter the instruction to apply to the selected text.")
        }
        .magicGlobalDropOverlay(isProcessing: isMagicImageProcessing) { data in
            extractMagicPrompt(from: data)
        }
    }
    private func performAIAction(_ action: AIAction, instruction: String? = nil) {
            let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
            let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty

            guard useGemini || useOpenAI else { return }

            if action == .instruct && instruction == nil {
                instructionInput = ""
                showingInstructionAlert = true
                return
            }

            isAIGenerating = true
            HapticService.shared.playImpact()
            withAnimation {
                branchMessage = "ai_thinking".localized(for: preferences.language)
            }

            // Cancelar cualquier generación previa antes de iniciar una nueva
            aiTask?.cancel()
            // Determinar qué fragmento procesar (selección o todo)
            let sourceText = plainTextContent.isEmpty ? content : plainTextContent
            let textToProcess: String
            let rangeToProcess: NSRange
            let fullNSString = sourceText as NSString

            if let sel = selectedRange, sel.length > 0 {
                textToProcess = fullNSString.substring(with: sel)
                rangeToProcess = sel
            } else {
                textToProcess = sourceText
                rangeToProcess = NSRange(location: 0, length: fullNSString.length)
            }

            guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isAIGenerating = false
                return
            }

            let contextInstruction = (action == .instruct) ? "\n\nPrompt Fragment:\n\(textToProcess)" : "\n\nPrompt Fragment:\n\(textToProcess)"
            let fullPrompt = (action == .instruct) ? "Execute the following instruction/command: \(instruction ?? "")\nRespond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"

            aiTask = Task {
                do {
                    let fullResponse = try await AIServiceManager.shared.generate(prompt: fullPrompt)
                    
                    await MainActor.run {
                        self.isAIGenerating = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            print("✅ AI Generation Success: \(fullResponse.count) characters")
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.aiResult = AIResult(result: resultString, range: rangeToProcess)
                        } else {
                            print("⚠️ AI Generation Finished with empty response")
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isAIGenerating = false
                        print("❌ AI Generation Error: \(error.localizedDescription)")
                        HapticService.shared.playError()
                        withAnimation {
                            self.branchMessage = self.userFacingAIErrorToast(for: error)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                        }
                }
            }
        }
    }

    private func userFacingAIErrorToast(for error: Error) -> String {
        let nsError = error as NSError

        let baseKey: String = {
            if let openAIError = error as? OpenAIAPIError {
                switch openAIError.kind {
                case .invalidAPIKey: return "ai_error_invalid_api_key"
                case .modelNotFound: return "ai_error_model_not_found"
                case .rateLimited: return "ai_error_rate_limited"
                case .serverBusy: return "ai_error_server_busy"
                case .badRequest: return "ai_error_bad_request"
                case .emptyResponse: return "ai_error_empty_response"
                case .unknown: return "ai_error_unknown"
                }
            }

            if nsError.domain == NSURLErrorDomain {
                return "ai_error_network"
            }

            if nsError.domain == "GeminiAPI" {
                switch nsError.code {
                case 400: return "ai_error_bad_request"
                case 401, 403: return "ai_error_invalid_api_key"
                case 404: return "ai_error_model_not_found"
                case 429: return "ai_error_rate_limited"
                case 500, 502, 503, 504: return "ai_error_server_busy"
                default: return "ai_error_unknown"
                }
            }

            let lower = nsError.localizedDescription.lowercased()
            if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
                return "ai_error_model_not_found"
            }
            if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("429") {
                return "ai_error_rate_limited"
            }
            if lower.contains("invalid api key") || (lower.contains("api key") && lower.contains("invalid")) || lower.contains("401") {
                return "ai_error_invalid_api_key"
            }
            if lower.contains("overloaded") || lower.contains("server busy") || lower.contains("503") {
                return "ai_error_server_busy"
            }

            return "ai_error_unknown"
        }()

        let base = baseKey.localized(for: preferences.language)
        let detail = compactErrorDetail(from: error)
        if detail.isEmpty {
            return "❌ \(base)"
        }
        return "❌ \(base)\n\(detail)"
    }

    private func compactErrorDetail(from error: Error) -> String {
        let raw: String = {
            if let openAIError = error as? OpenAIAPIError {
                return openAIError.message
            }
            return (error as NSError).localizedDescription
        }()

        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return "" }
        if cleaned.count <= 180 { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return String(cleaned[..<idx]) + "…"
    }

    private func createNewPromptFromEditor() {
        let newTitle = "New Prompt from Editor"
        let newPrompt = Prompt(
            title: newTitle,
            content: content,
            folder: (originalPrompt ?? prompt)?.folder,
            icon: (originalPrompt ?? prompt)?.icon ?? "doc.text.fill",
            tags: (originalPrompt ?? prompt)?.tags ?? []
        )

        if promptService.createPrompt(newPrompt) {
            HapticService.shared.playSuccess()
            withAnimation {
                branchMessage = "prompt_created_success".localized(for: preferences.language)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { branchMessage = nil }
            }
        }
    }
    
    private func extractMagicPrompt(from data: Data) {
        guard (!preferences.openAIApiKey.isEmpty && preferences.openAIEnabled) || (!preferences.geminiAPIKey.isEmpty && preferences.geminiEnabled) else { 
            title = "IA no configurada"
            return 
        }
        content = ""
        isMagicImageProcessing = true
        
        Task {
            do {
                let instruction = "Analiza la imagen adjunta y genera un título corto (máximo 4 palabras) y un prompt ultra-descriptivo para recrearla usando inteligencia artificial. Incluye detalles cinemáticos, sujetos centrales, paleta de colores y estilo artístico. Devuelve el resultado EXACTAMENTE en este formato:\nTITULO: [título aquí]\nPROMPT: [prompt completo aquí]"
                let systemPrompt = """
                You are an elite AI Art Director and Vision Assistant. Your task is to act exclusively on the provided image.
                
                # INSTRUCTION FOR YOU:
                \(instruction)
                
                # IMPORTANT:
                Respond ONLY with the format requested. Do not add quotes, markdown formatting, or introductory text.
                """
                
                let response = try await AIServiceManager.shared.generate(prompt: systemPrompt, imageData: data)
                
                await MainActor.run {
                    self.isMagicImageProcessing = false
                    
                    let rawResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    let components = rawResponse.components(separatedBy: "PROMPT:")
                    
                    if components.count == 2 {
                        let rawTitle = components[0].replacingOccurrences(of: "TITULO:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        self.content = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if self.title.isEmpty || self.title == "prompt_title_placeholder".localized(for: preferences.language) || self.title == "Prompt de Imagen" {
                            self.title = rawTitle.isEmpty ? "Prompt de Imagen" : rawTitle
                        }
                    } else {
                        self.content = rawResponse
                        if self.title.isEmpty || self.title == "prompt_title_placeholder".localized(for: preferences.language) {
                            self.title = "Prompt de Imagen"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isMagicImageProcessing = false
                    self.content = "Error generando prompt: \(error.localizedDescription)"
                }
            }
        }
    }
}

enum AIAction {
    case enhance, fix, concise, translate, instruct

    var systemPrompt: String {
        switch self {
        case .enhance: return "Enhance the following prompt to be more descriptive and effective, keeping the variables {{...}} exactly as they are. Respond ONLY with the improved prompt text."
        case .fix: return "Fix grammar and spelling errors in the following prompt, keeping variables {{...}} exactly as they are. Respond ONLY with the corrected text."
        case .concise: return "Make the following prompt more concise and direct, keeping variables {{...}} exactly as they are. Respond ONLY with the concise text."
        case .translate:
            let toEnglish = UserDefaults.standard.bool(forKey: "translateToEnglish")
            if toEnglish {
                return "Translate the following text strictly to English. Keep variables {{...}} exactly as they are. Respond ONLY with the translated text."
            } else {
                let preferredLang = Locale.preferredLanguages.first ?? "es"
                let langName = Locale(identifier: "en_US").localizedString(forIdentifier: preferredLang) ?? "the user's system language"
                return "Translate the following text strictly to \(langName). Keep variables {{...}} exactly as they are. Respond ONLY with the translated text."
            }
        case .instruct: return ""
        }
    }
}

struct SecondaryEditorCard<Actions: View>: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let color: Color

    private var themeColor: Color {
        preferences.isHaloEffectEnabled ? color : .blue
    }
    var focusRequest: Binding<Bool>? = nil
    var onZenMode: (() -> Void)? = nil

    // Bindings for standard actions
    @Binding var insertionRequest: String?
    @Binding var replaceSnippetRequest: String?
    @Binding var showSnippets: Bool
    @Binding var snippetSearchQuery: String
    @Binding var snippetSelectedIndex: Int
    @Binding var triggerSnippetSelection: Bool
    @Binding var showVariables: Bool
    @Binding var variablesSelectedIndex: Int
    @Binding var triggerVariablesSelection: Bool
    @Binding var triggerAIRequest: String?
    @Binding var isAIActive: Bool
    @Binding var isAIGenerating: Bool
    @Binding var selectedRange: NSRange?
    @Binding var aiResult: AIResult?
    @Binding var showingPremiumFor: String?
    var originalPrompt: Prompt?
    var prompt: Prompt?
    @Binding var branchMessage: String?
    let editorID: String
    let currentCategoryColor: Color

    let actions: Actions
    
    var isAutocompleting: Bool = false
    var onMagicAutocomplete: (() -> Void)? = nil

    @EnvironmentObject var promptService: PromptService
    @EnvironmentObject var preferences: PreferencesManager

    init(title: String, placeholder: String, text: Binding<String>, icon: String, color: Color,
         focusRequest: Binding<Bool>? = nil, onZenMode: (() -> Void)? = nil,
         insertionRequest: Binding<String?>, replaceSnippetRequest: Binding<String?>,
         showSnippets: Binding<Bool>, snippetSearchQuery: Binding<String>,
         snippetSelectedIndex: Binding<Int>, triggerSnippetSelection: Binding<Bool>,
         showVariables: Binding<Bool>, variablesSelectedIndex: Binding<Int>,
         triggerVariablesSelection: Binding<Bool>, triggerAIRequest: Binding<String?>,
         isAIActive: Binding<Bool>, isAIGenerating: Binding<Bool>,
         isAutocompleting: Bool = false, onMagicAutocomplete: (() -> Void)? = nil,
         selectedRange: Binding<NSRange?>, aiResult: Binding<AIResult?>,
         showingPremiumFor: Binding<String?>, originalPrompt: Prompt? = nil,
         prompt: Prompt? = nil, branchMessage: Binding<String?>,
         editorID: String, currentCategoryColor: Color,
         @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.color = color
        self.focusRequest = focusRequest
        self.onZenMode = onZenMode
        self._insertionRequest = insertionRequest
        self._replaceSnippetRequest = replaceSnippetRequest
        self._showSnippets = showSnippets
        self._snippetSearchQuery = snippetSearchQuery
        self._snippetSelectedIndex = snippetSelectedIndex
        self._triggerSnippetSelection = triggerSnippetSelection
        self._showVariables = showVariables
        self._variablesSelectedIndex = variablesSelectedIndex
        self._triggerVariablesSelection = triggerVariablesSelection
        self._triggerAIRequest = triggerAIRequest
        self._isAIActive = isAIActive
        self._isAIGenerating = isAIGenerating
        self._selectedRange = selectedRange
        self._aiResult = aiResult
        self._showingPremiumFor = showingPremiumFor
        self.isAutocompleting = isAutocompleting
        self.onMagicAutocomplete = onMagicAutocomplete
        self.originalPrompt = originalPrompt
        self.prompt = prompt
        self._branchMessage = branchMessage
        self.editorID = editorID
        self.currentCategoryColor = currentCategoryColor
        self.actions = actions()
    }

    private var isAIAvailable: Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }

    @State private var isEditorFocused: Bool = false
    @State private var isHovering: Bool = false
    @State private var isTyping: Bool = false
    @State private var showingPromptChainPicker: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var plainTextContent: String = ""
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var showingInstructionAlert = false
    @State private var instructionInput = ""

    var body: some View {
        let iconColor: Color = (icon == "hand.raised.fill") ? Color.red.opacity(0.8) : themeColor

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)

                if String(describing: actions) != "EmptyView" {
                    actions
                        .padding(.leading, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            // ✅ Editor Secundario con Herramientas Inteligentes (Sidebar Layout)
            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HighlightedEditor(
                        text: $text,
                        plainText: $plainTextContent,
                        insertionRequest: $insertionRequest,
                        replaceSnippetRequest: $replaceSnippetRequest,
                        triggerAIRequest: $triggerAIRequest,
                        isAIActive: $isAIActive,
                        editorID: editorID,
                        isFocused: $isEditorFocused,
                        focusRequest: focusRequest,
                        selectedRange: $selectedRange,
                        aiResult: $aiResult,
                        fontSize: 14 * preferences.fontSize.scale,
                        themeColor: NSColor(color),
                        showSnippets: $showSnippets,
                        snippetSearchQuery: $snippetSearchQuery,
                        snippetSelectedIndex: $snippetSelectedIndex,
                        triggerSnippetSelection: $triggerSnippetSelection,
                        showVariables: $showVariables,
                        variablesSelectedIndex: $variablesSelectedIndex,
                        triggerVariablesSelection: $triggerVariablesSelection,
                        isPremium: preferences.isPremiumActive,
                        isHaloEffectEnabled: preferences.isHaloEffectEnabled,
                        isTyping: $isTyping
                    )
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 5) // Espacio sutil de 5px
                    .frame(maxWidth: .infinity, minHeight: 180) // Aumentado para que sea más espacioso

                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14 * preferences.fontSize.scale))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.leading, 22)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

                // Herramientas Laterales (Compactas)
                EditorToolbar(
                    color: color,
                    editorID: editorID,
                    vertical: true,
                    content: $text,
                    selectedRange: $selectedRange,
                    isAIGenerating: isAIGenerating,
                    onAIAction: { performAIAction($0) },
                    aiEnabled: isAIAvailable,
                    onShowVariables: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showVariables.toggle()
                                variablesSelectedIndex = 0
                            }
                        } else {
                            showingPremiumFor = "dynamic_variables".localized(for: preferences.language)
                        }
                    },
                    onShowSnippets: {
                        if preferences.isPremiumActive {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSnippets.toggle()
                                snippetSearchQuery = ""
                            }
                        } else {
                            showingPremiumFor = "reusable_snippets".localized(for: preferences.language)
                        }
                    },
                    showingPromptChainPicker: $showingPromptChainPicker,
                    chainPopoverContent: {
                        AnyView(
                            PromptPickerPopover(excludePromptId: prompt?.id) { selected in
                                insertionRequest = "[[@Prompt:\(selected.title)]]"
                                showingPromptChainPicker = false
                            }
                        )
                    },
                    onZenMode: {
                        onZenMode?()
                    },
                    onFloatingMode: nil,
                    isAutocompleting: isAIGenerating,
                    onMagicAutocomplete: isAIAvailable
                        ? {
                            if let onMagicAutocomplete {
                                onMagicAutocomplete()
                            } else {
                                performAIAction(.enhance)
                            }
                        }
                        : nil
                )
                .scaleEffect(0.9)
                .padding(.vertical, 8)
                .padding(.trailing, 4) // Ajustado para ahorrar espacio lateral
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(isTyping ? 0.8 : (isHovering ? 0.5 : 0.3)), lineWidth: isTyping ? 2 : 1.5)
                            .shadow(color: preferences.isHaloEffectEnabled ? themeColor.opacity(isTyping ? 0.4 : (isHovering ? 0.2 : 0.1)) : .clear, radius: isTyping ? 10 : (isHovering ? 6 : 4))
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isEditorFocused)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(isTyping ? .spring(response: 0.35, dampingFraction: 0.7) : .easeOut(duration: 1.5), value: isTyping)
            .contentShape(Rectangle()) // <---- CRITICAL: Evita zonas muertas transparentes
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditorFocused = true
                }
            }
        }
        .alert("Execute Command", isPresented: $showingInstructionAlert) {
            TextField("Instruction (e.g. Translate to French)", text: $instructionInput)
            Button("Cancel", role: .cancel) { }
            Button("Execute") {
                performAIAction(.instruct, instruction: instructionInput)
            }
        } message: {
            Text("Enter the instruction to apply to the selected text.")
        }
    }
                private func performAIAction(_ action: AIAction, instruction: String? = nil) {
                    let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
                    let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        
                    guard useGemini || useOpenAI else { return }
        
                    if action == .instruct && instruction == nil {
                        instructionInput = ""
                        showingInstructionAlert = true
                        return
                    }
        
                    isAIGenerating = true
                    HapticService.shared.playImpact()
                    withAnimation {
                        branchMessage = "ai_thinking".localized(for: preferences.language)
                    }
        
                    aiTask?.cancel()
                    // Determinar qué fragmento procesar
                    let sourceText = plainTextContent.isEmpty ? text : plainTextContent
                    let textToProcess: String
                    let rangeToProcess: NSRange
                    let fullNSString = sourceText as NSString
        
                    if let sel = selectedRange, sel.length > 0 {
                        textToProcess = fullNSString.substring(with: sel)
                        rangeToProcess = sel
                    } else {
                        textToProcess = sourceText
                        rangeToProcess = NSRange(location: 0, length: fullNSString.length)
                    }
        
                    guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        isAIGenerating = false
                        return
                    }
        
                    let contextInstruction = (action == .instruct) ? "\n\nPrompt Fragment:\n\(textToProcess)" : "\n\nPrompt Fragment:\n\(textToProcess)"
                    let fullPrompt = (action == .instruct) ? "Execute the following instruction/command: \(instruction ?? "")\nRespond ONLY with the result:\n\(textToProcess)" : "\(action.systemPrompt)\(contextInstruction)"
        
                    aiTask = Task {                do {
                    let fullResponse = try await AIServiceManager.shared.generate(prompt: fullPrompt)
                    
                    await MainActor.run {
                        self.isAIGenerating = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        if !fullResponse.isEmpty {
                            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.aiResult = AIResult(result: resultString, range: rangeToProcess)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isAIGenerating = false
                        HapticService.shared.playError()
                        withAnimation {
                            self.branchMessage = self.userFacingAIErrorToast(for: error)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                        }
                    }
                }
            }
        }

        private func userFacingAIErrorToast(for error: Error) -> String {
            let nsError = error as NSError

            let baseKey: String = {
                if let openAIError = error as? OpenAIAPIError {
                    switch openAIError.kind {
                    case .invalidAPIKey: return "ai_error_invalid_api_key"
                    case .modelNotFound: return "ai_error_model_not_found"
                    case .rateLimited: return "ai_error_rate_limited"
                    case .serverBusy: return "ai_error_server_busy"
                    case .badRequest: return "ai_error_bad_request"
                    case .emptyResponse: return "ai_error_empty_response"
                    case .unknown: return "ai_error_unknown"
                    }
                }

                if nsError.domain == NSURLErrorDomain {
                    return "ai_error_network"
                }

                if nsError.domain == "GeminiAPI" {
                    switch nsError.code {
                    case 400: return "ai_error_bad_request"
                    case 401, 403: return "ai_error_invalid_api_key"
                    case 404: return "ai_error_model_not_found"
                    case 429: return "ai_error_rate_limited"
                    case 500, 502, 503, 504: return "ai_error_server_busy"
                    default: return "ai_error_unknown"
                    }
                }

                let lower = nsError.localizedDescription.lowercased()
                if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
                    return "ai_error_model_not_found"
                }
                if lower.contains("rate limit") || lower.contains("too many requests") || lower.contains("429") {
                    return "ai_error_rate_limited"
                }
                if lower.contains("invalid api key") || (lower.contains("api key") && lower.contains("invalid")) || lower.contains("401") {
                    return "ai_error_invalid_api_key"
                }
                if lower.contains("overloaded") || lower.contains("server busy") || lower.contains("503") {
                    return "ai_error_server_busy"
                }

                return "ai_error_unknown"
            }()

            let base = baseKey.localized(for: preferences.language)
            let detail = compactErrorDetail(from: error)
            if detail.isEmpty {
                return "❌ \(base)"
            }
            return "❌ \(base)\n\(detail)"
        }

        private func compactErrorDetail(from error: Error) -> String {
            let raw: String = {
                if let openAIError = error as? OpenAIAPIError {
                    return openAIError.message
                }
                return (error as NSError).localizedDescription
            }()

            let cleaned = raw
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if cleaned.isEmpty { return "" }
            if cleaned.count <= 180 { return cleaned }
            let idx = cleaned.index(cleaned.startIndex, offsetBy: 180)
            return String(cleaned[..<idx]) + "…"
        }
    private func createNewPromptFromEditor() {
        let newTitle = "New Prompt from Editor"
        let newPrompt = Prompt(
            title: newTitle,
            content: text,
            folder: (originalPrompt ?? prompt)?.folder,
            icon: "doc.text.fill",
            tags: []
        )

        if promptService.createPrompt(newPrompt) {
            HapticService.shared.playSuccess()
        }
    }
}

