
enum MagicTarget: String, CaseIterable, Identifiable {
    case title = "Título"
    case description = "Descripción"
    case content = "Prompt"
    var id: String { self.rawValue }
}

import SwiftUI
import Combine

@MainActor
final class NewPromptViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var negativePrompt = ""
    @Published var alternatives: [String] = []
    @Published var alternativeDescriptions: [String] = []
    @Published var promptDescription = ""
    @Published var selectedFolder: String?
    @Published var isFavorite = false
    @Published var selectedIcon: String?
    @Published var showcaseImages: [Data] = []
    @Published var isSaving = false
    
    @Published var tags: [String] = []
    
    @Published var targetAppBundleIDs: [String] = []
    @Published var customShortcut: String? = nil
    
    @Published var originalPrompt: Prompt?
    
    
    // AI & Magic States
    @Published var showingPremiumFor: String? = nil
    @Published var showingMagicOptions: Bool = false
    @Published var showingCreationOptions: Bool = false
    @Published var branchMessage: String? = nil
    @Published var isAutocompleting: Bool = false
    @Published var isCategorizing: Bool = false
    @Published var showNegativeField: Bool = false
    @Published var showAlternativeField: Bool = false
    @Published var magicCommand: String = ""
    @Published var magicTarget: MagicTarget = .content
    @Published var isGeneratingAlternativeDirect: Bool = false
    @Published var isMagicImageProcessing: Bool = false
    @Published var showingAIPrefs: Bool = false

    private var draftHash: Int = 0
    
    var promptId: UUID? {
        originalPrompt?.id
    }
    
    init(prompt: Prompt? = nil, initialFolder: String? = nil) {
        self.originalPrompt = prompt
        
        if let prompt = prompt {
            self.title = prompt.title
            self.content = prompt.content
            self.negativePrompt = prompt.negativePrompt ?? ""
            self.alternatives = prompt.alternatives
            self.alternativeDescriptions = prompt.alternativeDescriptions
            self.promptDescription = prompt.promptDescription ?? ""
            self.selectedFolder = prompt.folder
            self.tags = prompt.tags
            self.isFavorite = prompt.isFavorite
            self.selectedIcon = prompt.icon
            self.showcaseImages = prompt.showcaseImages
            self.targetAppBundleIDs = prompt.targetAppBundleIDs
            self.customShortcut = prompt.customShortcut
        } else if let folder = initialFolder {
            self.selectedFolder = folder
        }

        normalizeAlternativeDescriptions()
        
        updateDraftHash()
    }
    
    
    // MARK: - AI Magic Features
    
    func userFacingAIErrorToast(for error: Error, language: AppLanguage) -> String {
        let nsError = error as NSError
        
        let baseKey: String = {
            if nsError.domain == NSURLErrorDomain {
                if nsError.code == NSURLErrorNotConnectedToInternet {
                    return "error_no_internet"
                } else if nsError.code == NSURLErrorTimedOut {
                    return "error_timeout"
                }
                return "error_network"
            }
            if let aiError = error as? AIServiceManager.AIError {
                switch aiError {
                case .serviceDisabled: return "error_service_disabled"
                case .invalidAPIKey: return "error_invalid_key"
                case .configurationError: return "error_config"
                }
            }
            return "error_generic_ai"
        }()
        
        return "❌ " + baseKey.localized(for: language)
    }

    func autocompletePromptContent(preferences: PreferencesManager, promptService: PromptService) {
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            HapticService.shared.playError()
            return
        }
        
        if !trimmedTitle.isEmpty && !trimmedContent.isEmpty {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingMagicOptions = true
            }
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showingCreationOptions = true
        }
    }

    func executeAutocomplete(preferences: PreferencesManager, promptService: PromptService, keepContent: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showingCreationOptions = false
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isAutocompleting = true
        HapticService.shared.playImpact()
        
        withAnimation {
            branchMessage = "ai_thinking".localized(for: preferences.language)
        }
        
        let systemPrompt: String
        let currentTitle = trimmedTitle.isEmpty ? "No title provided" : trimmedTitle
        let currentContent = trimmedContent.isEmpty ? "No content provided" : trimmedContent
        
        let titleInstruction = !trimmedTitle.isEmpty
            ? "The title is already provided. DO NOT modify it in any way. Return it EXACTLY as it is."
            : "If the title is empty or generic, generate a catchy, short title (max 1 line)."

        let contentInstruction: String
        if keepContent && !trimmedContent.isEmpty {
            contentInstruction = "The content is already provided by the user. DO NOT modify it, do not expand it, and do not improve it. Return it EXACTLY as it is."
        } else if !keepContent && !trimmedContent.isEmpty {
            contentInstruction = "The user has provided a base idea or instructions in the 'Content' field. Treat that input as INSTRUCTIONS to generate a brand new, high-quality, detailed prompt from scratch. Expand their idea into a full prompt. Maintain EXISTING variables {{...}}. If you must create new variables, use a MAXIMUM of 3. New variables MUST use exact syntax {{snake_case_name}} (e.g. {{web_folder_path}}). NEVER USE ITALICS OR BOLD FORMATTING AROUND VARIABLES. For example, never output *{{variable}}* or _{{variable}}_, just output {{variable}} cleanly."
        } else {
            contentInstruction = "Generate the main prompt content based on the title. It must be high-quality and detailed. Maintain EXISTING variables {{...}}. If you must create new variables, use a MAXIMUM of 3. New variables MUST use exact syntax {{snake_case_name}} (e.g. {{web_folder_path}}). NEVER USE ITALICS OR BOLD FORMATTING AROUND VARIABLES. For example, never output *{{variable}}* or _{{variable}}_, just output {{variable}} cleanly."
        }

        systemPrompt = """
        You are an expert prompt engineer. Your goal is to create or improve an AI prompt based on the user's input.
        
        INPUTS:
        - Title: \(currentTitle)
        - Content: \(currentContent)
        
        INSTRUCTIONS:
        1. TITLE: \(titleInstruction)
        2. DESCRIPTION: Generate a concise description of what this prompt does (max 2 lines).
        3. CONTENT: \(contentInstruction)
        4. NEGATIVE PROMPT: Generate a list of practical things to AVOID for this prompt (e.g. "no formatting errors, no generic tone", etc).
        
        CRITICAL LANGUAGE RULE:
        - Detect the PRIMARY language of the user's input (title and content).
        - You MUST respond ENTIRELY in that SAME language. Every word of your response — title, description, content, negative prompt, variable names — must be in the input's language.
        - If input is Spanish → respond in Spanish. If English → respond in English. Never mix languages.
        
        RESPONSE FORMAT:
        Respond ONLY with the following format, using the pipe symbol (|) as separator:
        GeneratedTitle|GeneratedDescription|GeneratedContent|GeneratedNegativePrompt
        
        DO NOT include any other text, labels, or explanations. Just the FOUR parts separated by |.
        """
        
        Task {
            do {
                let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    HapticService.shared.playSuccess()
                    
                    if !fullResponse.isEmpty {
                        let parts = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
                        if parts.count >= 4 {
                            withAnimation(.spring()) {
                                self.title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.promptDescription = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.content = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                let nPrompt = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                                if !nPrompt.isEmpty {
                                    self.negativePrompt = nPrompt
                                    self.showNegativeField = true
                                }
                            }
                            
                            if self.selectedFolder == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.autoCategorizePrompt(preferences: preferences, promptService: promptService)
                                }
                            }
                        } else if parts.count >= 3 {
                            withAnimation(.spring()) {
                                self.title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.promptDescription = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                self.content = parts.dropFirst(2).joined(separator: "|").trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            if self.selectedFolder == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.autoCategorizePrompt(preferences: preferences, promptService: promptService)
                                }
                            }
                        } else if !fullResponse.contains("|") {
                            withAnimation(.spring()) {
                                self.content = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error, language: preferences.language)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }

    func executeMagicWithCommand(preferences: PreferencesManager) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showingMagicOptions = false
        }
        
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        isAutocompleting = true
        HapticService.shared.playImpact()
        
        withAnimation {
            branchMessage = "ai_thinking".localized(for: preferences.language)
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = magicCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var targetContext = ""
        var systemInstruction = ""
        
        switch magicTarget {
        case .title:
            targetContext = "Current Prompt Content: \(trimmedContent)"
            systemInstruction = command.isEmpty ? "Generate a catchy, short title (max 1 line) for the prompt content. Maintain the language. Respond ONLY with the new title." : "Modify ONLY the title based on this instruction: '\(command)'. Maintain the language. Respond ONLY with the new title."
        case .description:
            targetContext = "Current Prompt Content: \(trimmedContent)\nCurrent Title: \(trimmedTitle)"
            systemInstruction = command.isEmpty ? "Generate a concise description (max 2 lines) for the prompt content. Maintain the language. Respond ONLY with the new description." : "Modify ONLY the description based on this instruction: '\(command)'. Maintain the language. Respond ONLY with the new description."
        case .content:
            targetContext = "Current Content: \(trimmedContent)"
            systemInstruction = "Modify ONLY the prompt content based on this instruction: '\(command)'. Maintain ANY variables {{...}} exactly as they are. Maintain the language. Respond ONLY with the newly modified content text."
        }
        
        let systemPrompt = """
        You are an expert prompt engineer. Your goal is to modify a specific part of an AI prompt.
        
        \(targetContext)
        
        INSTRUCTION:
        \(systemInstruction)
        
        CRITICAL RULE:
        - Respond ONLY with the raw new text. No quotes, no markdown, no introductory phrases. Just the exact replacement text.
        """
        
        Task {
            do {
                if magicTarget == .content {
                    let negativeSystemPrompt = """
                    You are an expert AI prompt engineer. Your task is to generate a highly effective and targeted NEGATIVE PROMPT (behaviors or clichés the AI should AVOID) based on the user's topic: '\(command)'.
                    Maintain the EXACT SAME LANGUAGE as the original topic.
                    
                    CRITICAL RULE:
                    - Respond ONLY with the raw negative prompt text. No quotes, no introductions, no labels.
                    """
                    
                    let alternativeSystemPrompt = """
                    You are an expert prompt engineer. Your goal is to generate an ALTERNATIVE PROMPT variation.
                    
                    INSTRUCTION:
                    Based on the instruction '\(command)' and context '\(targetContext)', generate ONE alternative version.
                    Maintain the EXACT SAME LANGUAGE as the prompt content.
                    Maintain ALL variables {{...}} exactly as they are.
                    
                    CRITICAL RULE:
                    - Respond ONLY with the final alternative prompt text.
                    - Do NOT add quotes, labels, or conversational filler.
                    """
                    
                    async let mainResponseTask = AIServiceManager.shared.generate(prompt: systemPrompt)
                    async let negativeResponseTask = AIServiceManager.shared.generate(prompt: negativeSystemPrompt)
                    async let alternativeResponseTask = AIServiceManager.shared.generate(prompt: alternativeSystemPrompt)
                    
                    let fullResponse = try await mainResponseTask
                    let negativeResponseRaw = try await negativeResponseTask
                    let alternativeResponseRaw = try await alternativeResponseTask
                    
                    let negativeResponse = negativeResponseRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let alternativeResponse = alternativeResponseRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let alternativeDescriptionResponse: String
                    if alternativeResponse.isEmpty {
                        alternativeDescriptionResponse = ""
                    } else {
                        let descriptionPrompt = buildAlternativeDescriptionPrompt(for: alternativeResponse)
                        alternativeDescriptionResponse = (try? await AIServiceManager.shared.generate(prompt: descriptionPrompt)) ?? ""
                    }
                    
                    await MainActor.run {
                        self.isAutocompleting = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        
                        let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !result.isEmpty {
                            withAnimation(.spring()) {
                                self.content = result
                                if !negativeResponse.isEmpty {
                                    self.negativePrompt = negativeResponse
                                    self.showNegativeField = true
                                }
                                if !alternativeResponse.isEmpty {
                                    if !self.alternatives.contains(alternativeResponse) {
                                        self.alternatives.append(alternativeResponse)
                                        self.alternativeDescriptions.append(self.normalizedAlternativeDescription(alternativeDescriptionResponse))
                                    }
                                    self.showAlternativeField = true
                                }
                            }
                        }
                    }
                } else {
                    let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                    
                    await MainActor.run {
                        self.isAutocompleting = false
                        withAnimation { self.branchMessage = nil }
                        HapticService.shared.playSuccess()
                        
                        let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !result.isEmpty {
                            withAnimation(.spring()) {
                                switch magicTarget {
                                case .title: self.title = result
                                case .description: self.promptDescription = result
                                case .content: self.content = result
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAutocompleting = false
                    withAnimation { self.branchMessage = nil }
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error, language: preferences.language)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }


    func generateAlternativeDirect(preferences: PreferencesManager) {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty else { return }

        isGeneratingAlternativeDirect = true
        HapticService.shared.playImpact()

        let systemPrompt = """
        Eres un ingeniero de prompts experto y creativo. Genera una versión ALTERNATIVA o variada del siguiente prompt.
        MANTÉN EL MISMO IDIOMA EXACTO DEL PROMPT ORIGINAL.
        MANTEN TODAS Y CADA UNA de las variables entre llaves (ejemplo: {{ejemplo}}) exactamente intactas.
        Tu respuesta debe ser EXCLUSIVAMENTE el texto de la alternativa, sin títulos, explicaciones, comillas ni comentarios extra. Dámelo plano.

        PROMPT ORIGINAL:
        \(cleanContent)
        """

        Task {
            do {
                let response = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                let generatedDescription: String
                if cleanedResponse.isEmpty {
                    generatedDescription = ""
                } else {
                    let descriptionPrompt = self.buildAlternativeDescriptionPrompt(for: cleanedResponse)
                    generatedDescription = (try? await AIServiceManager.shared.generate(prompt: descriptionPrompt)) ?? ""
                }
                
                await MainActor.run {
                    self.isGeneratingAlternativeDirect = false
                    if !cleanedResponse.isEmpty {
                        withAnimation(.spring()) {
                            self.alternatives.append(cleanedResponse)
                            self.alternativeDescriptions.append(self.normalizedAlternativeDescription(generatedDescription))
                            self.showAlternativeField = true
                        }
                        HapticService.shared.playSuccess()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingAlternativeDirect = false
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error, language: preferences.language)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { self.branchMessage = nil }
                    }
                }
            }
        }
    }

    func autoCategorizePrompt(preferences: PreferencesManager, promptService: PromptService) {
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else { return }

        let skipCategory = (selectedFolder != nil)
        
        isCategorizing = true
        
        let availableFolders = promptService.folders.map { $0.name }
        if availableFolders.isEmpty {
            isCategorizing = false
            return
        }
        
        let categoriesStr = availableFolders.joined(separator: ", ")
        let validIcons = [
            "brain.fill", "sparkles", "bolt.fill", "lightbulb.fill", "cpu.fill", "network", "wand.and.stars", "atom",
            "terminal.fill", "chevron.left.forwardslash.chevron.right", "curlybraces", "command.circle.fill",
            "gearshape.fill", "wrench.fill", "hammer.fill", "puzzlepiece.fill", "shippingbox.fill",
            "doc.text.fill", "pencil.and.outline", "text.quote", "book.closed.fill", "square.and.pencil",
            "note.text", "doc.richtext.fill", "list.bullet.indent", "character.bubble.fill",
            "chart.line.uptrend.xyaxis", "chart.bar.fill", "target", "briefcase.fill", "dollarsign.circle.fill",
            "tag.fill", "bookmark.fill", "link",
            "bubble.left.and.bubble.right.fill", "paperplane.fill", "megaphone.fill", "person.fill",
            "envelope.fill", "heart.fill", "message.fill",
            "photo.fill", "camera.fill", "paintpalette.fill", "film.fill", "mic.fill", "headphones",
            "video.fill", "scissors", "eye.fill", "music.note", "play.circle.fill",
            "star.fill", "flame.fill", "flag.fill", "bell.fill", "lock.fill", "key.fill",
            "calendar", "map.fill", "gift.fill", "gamecontroller.fill", "trophy.fill",
            "globe", "leaf.fill", "house.fill", "graduationcap.fill",
            "sun.max.fill", "moon.fill", "cloud.fill"
        ]
        let iconListString = validIcons.joined(separator: ", ")

        let categoryInstruction = skipCategory
            ? "The category is already set. Do NOT return a category. Respond ONLY with the icon name."
            : "Select the best category from this list: [\(categoriesStr)]."

        let formatInstruction = skipCategory
            ? "Respond ONLY with the SF Symbol name (e.g. terminal.fill). Nothing else."
            : "Format your response EXACTLY as: CategoryName|SymbolName. Respond ONLY with this format, nothing else."

        let systemPrompt = """
        Based on the title '\(trimmedTitle)' and content '\(trimmedContent)', \(categoryInstruction)
        Also suggest the most appropriate SF Symbol icon from ONLY this exact list: [\(iconListString)].
        You MUST choose from this list. Do NOT invent icon names.
        \(formatInstruction)
        """
        
        Task {
            do {
                let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                await MainActor.run {
                    self.isCategorizing = false
                    let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)

                    if skipCategory {
                        if IconPickerView.allIconNames.contains(result) {
                            withAnimation(.spring()) {
                                self.selectedIcon = result
                            }
                        }
                    } else {
                        let parts = result.components(separatedBy: "|")
                        if parts.count == 2 {
                            let folder = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let iconName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            withAnimation(.spring()) {
                                if availableFolders.contains(folder) {
                                    self.selectedFolder = folder
                                }
                                if IconPickerView.allIconNames.contains(iconName) {
                                    self.selectedIcon = iconName
                                }
                            }
                            HapticService.shared.playSuccess()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCategorizing = false
                    HapticService.shared.playError()
                    withAnimation {
                        self.branchMessage = self.userFacingAIErrorToast(for: error, language: preferences.language)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation { if self.branchMessage?.hasPrefix("❌") == true { self.branchMessage = nil } }
                    }
                }
            }
        }
    }

    func updateDraftHash() {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(negativePrompt)
        hasher.combine(alternatives)
        hasher.combine(alternativeDescriptions)
        hasher.combine(promptDescription)
        hasher.combine(selectedFolder)
        draftHash = hasher.finalize()
    }
    
    func hasUnsavedChanges() -> Bool {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(content)
        hasher.combine(negativePrompt)
        hasher.combine(alternatives)
        hasher.combine(alternativeDescriptions)
        hasher.combine(promptDescription)
        hasher.combine(selectedFolder)
        return draftHash != hasher.finalize()
    }
    
    func savePrompt(promptService: PromptService, onClose: (() -> Void)? = nil) {
        guard !title.isEmpty, !content.isEmpty else { return }
        
        // Setup updated object
        let newNegativePrompt: String? = negativePrompt.isEmpty ? nil : negativePrompt
        
        let existingPrompt = originalPrompt
        if existingPrompt != nil {
            var updated = existingPrompt!
            updated.title = title
            updated.content = content
            updated.promptDescription = promptDescription.isEmpty ? nil : promptDescription
            updated.folder = selectedFolder
            updated.isFavorite = isFavorite
            updated.icon = selectedIcon
            updated.showcaseImages = showcaseImages
            updated.tags = tags
            updated.negativePrompt = newNegativePrompt
            updated.alternatives = alternatives
            updated.alternativeDescriptions = alternativeDescriptions
            updated.targetAppBundleIDs = targetAppBundleIDs
            updated.customShortcut = customShortcut
            updated.modifiedAt = Date()
            
            _ = promptService.updatePrompt(updated)
            self.originalPrompt = updated
        } else {
            var new = Prompt(
                title: title,
                content: content,
                promptDescription: promptDescription.isEmpty ? nil : promptDescription,
                folder: selectedFolder,
                icon: selectedIcon,
                showcaseImages: showcaseImages,
                tags: tags,
                targetAppBundleIDs: targetAppBundleIDs,
                negativePrompt: newNegativePrompt,
                alternatives: alternatives,
                alternativeDescriptions: alternativeDescriptions,
                customShortcut: customShortcut
            )
            new.isFavorite = isFavorite
            _ = promptService.createPrompt(new)
            self.originalPrompt = new
        }
        
        DraftService.shared.clearDraft()
        onClose?()
    }

    private func normalizeAlternativeDescriptions() {
        if alternativeDescriptions.count < alternatives.count {
            alternativeDescriptions.append(contentsOf: Array(repeating: "", count: alternatives.count - alternativeDescriptions.count))
        } else if alternativeDescriptions.count > alternatives.count {
            alternativeDescriptions = Array(alternativeDescriptions.prefix(alternatives.count))
        }
    }

    private func normalizedAlternativeDescription(_ raw: String) -> String {
        let oneLine = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(oneLine.prefix(120))
    }

    private func buildAlternativeDescriptionPrompt(for alternativeText: String) -> String {
        """
        You are an expert prompt editor.
        Write a concise one-line description (max 12 words) for this alternative prompt.
        Keep the SAME language as the prompt.
        Return ONLY the description text. No quotes, no labels, no markdown.

        Alternative prompt:
        \(alternativeText)
        """
    }

    func extractMagicPrompt(from data: Data, preferences: PreferencesManager) {
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
