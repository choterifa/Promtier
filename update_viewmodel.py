import re

path = "/Users/valencia/Downloads/Apps Menu Bar/Promtier/Promtier/ViewModels/NewPromptViewModel.swift"
with open(path, "r") as f:
    content = f.read()

enum_def = """
enum MagicTarget: String, CaseIterable, Identifiable {
    case title = "Título"
    case description = "Descripción"
    case content = "Prompt"
    var id: String { self.rawValue }
}
"""

new_states = """
    // AI & Magic States
    @Published var showingPremiumFor: String? = nil
    @Published var showingMagicOptions: Bool = false
    @Published var branchMessage: String? = nil
    @Published var isAutocompleting: Bool = false
    @Published var isCategorizing: Bool = false
    @Published var showNegativeField: Bool = false
    @Published var showAlternativeField: Bool = false
    @Published var magicCommand: String = ""
    @Published var magicTarget: MagicTarget = .content
    @Published var isGeneratingAlternativeDirect: Bool = false
"""

new_methods = """
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
                case .allServicesFailed: return "error_api_saturation"
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
        
        isAutocompleting = true
        HapticService.shared.playImpact()
        
        withAnimation {
            branchMessage = "ai_thinking".localized(for: preferences.language)
        }
        
        let systemPrompt: String
        let currentTitle = trimmedTitle.isEmpty ? "No title provided" : trimmedTitle
        let currentContent = trimmedContent.isEmpty ? "No content provided" : trimmedContent
        
        let isContentProvided = !trimmedContent.isEmpty
        let isTitleProvided = !trimmedTitle.isEmpty
        
        let titleInstruction = isTitleProvided
            ? "The title is already provided. DO NOT modify it in any way. Return it EXACTLY as it is."
            : "If the title is empty or generic, generate a catchy, short title (max 1 line)."

        let contentInstruction = isContentProvided
            ? "The content is already provided by the user. DO NOT modify it, do not expand it, and do not improve it. Return it EXACTLY as it is."
            : "Generate the main prompt content. It must be high-quality and detailed. Maintain EXISTING variables {{...}}. If you must create new variables, use a MAXIMUM of 3. New variables MUST use exact syntax {{snake_case_name}} (e.g. {{web_folder_path}}). NEVER USE ITALICS OR BOLD FORMATTING AROUND VARIABLES. For example, never output *{{variable}}* or _{{variable}}_, just output {{variable}} cleanly."

        systemPrompt = \"\"\"
        You are an expert prompt engineer. Your goal is to create or improve an AI prompt based on the user's input.
        
        INPUTS:
        - Title: \\(currentTitle)
        - Content: \\(currentContent)
        
        INSTRUCTIONS:
        1. TITLE: \\(titleInstruction)
        2. DESCRIPTION: Generate a concise description of what this prompt does (max 2 lines).
        3. CONTENT: \\(contentInstruction)
        4. NEGATIVE PROMPT: Generate a list of practical things to AVOID for this prompt (e.g. "no formatting errors, no generic tone", etc).
        
        CRITICAL LANGUAGE RULE:
        - Detect the PRIMARY language of the user's input (title and content).
        - You MUST respond ENTIRELY in that SAME language. Every word of your response — title, description, content, negative prompt, variable names — must be in the input's language.
        - If input is Spanish → respond in Spanish. If English → respond in English. Never mix languages.
        
        RESPONSE FORMAT:
        Respond ONLY with the following format, using the pipe symbol (|) as separator:
        GeneratedTitle|GeneratedDescription|GeneratedContent|GeneratedNegativePrompt
        
        DO NOT include any other text, labels, or explanations. Just the FOUR parts separated by |.
        \"\"\"
        
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
            targetContext = "Current Prompt Content: \\(trimmedContent)"
            systemInstruction = command.isEmpty ? "Generate a catchy, short title (max 1 line) for the prompt content. Maintain the language. Respond ONLY with the new title." : "Modify ONLY the title based on this instruction: '\\(command)'. Maintain the language. Respond ONLY with the new title."
        case .description:
            targetContext = "Current Prompt Content: \\(trimmedContent)\\nCurrent Title: \\(trimmedTitle)"
            systemInstruction = command.isEmpty ? "Generate a concise description (max 2 lines) for the prompt content. Maintain the language. Respond ONLY with the new description." : "Modify ONLY the description based on this instruction: '\\(command)'. Maintain the language. Respond ONLY with the new description."
        case .content:
            targetContext = "Current Content: \\(trimmedContent)"
            systemInstruction = "Modify ONLY the prompt content based on this instruction: '\\(command)'. Maintain ANY variables {{...}} exactly as they are. Maintain the language. Respond ONLY with the newly modified content text."
        }
        
        let systemPrompt = \"\"\"
        You are an expert prompt engineer. Your goal is to modify a specific part of an AI prompt.
        
        \\(targetContext)
        
        INSTRUCTION:
        \\(systemInstruction)
        
        CRITICAL RULE:
        - Respond ONLY with the raw new text. No quotes, no markdown, no introductory phrases. Just the exact replacement text.
        \"\"\"
        
        Task {
            do {
                if magicTarget == .content && command.isEmpty {
                    let negativeSystemPrompt = \"\"\"
                    You are an expert AI prompt engineer. Your task is to generate a highly effective and targeted NEGATIVE PROMPT (behaviors or clichés the AI should AVOID) based on the user's topic: '\\(command)'.
                    Maintain the EXACT SAME LANGUAGE as the original topic.
                    
                    CRITICAL RULE:
                    - Respond ONLY with the raw negative prompt text. No quotes, no introductions, no labels.
                    \"\"\"
                    
                    let alternativeSystemPrompt = \"\"\"
                    You are an expert prompt engineer. Your goal is to generate an ALTERNATIVE PROMPT variation.
                    
                    INSTRUCTION:
                    Based on the instruction '\\(command)' and context '\\(targetContext)', generate ONE alternative version.
                    Maintain the EXACT SAME LANGUAGE as the prompt content.
                    Maintain ALL variables {{...}} exactly as they are.
                    
                    CRITICAL RULE:
                    - Respond ONLY with the final alternative prompt text.
                    - Do NOT add quotes, labels, or conversational filler.
                    \"\"\"
                    
                    async let mainResponseTask = AIServiceManager.shared.generate(prompt: systemPrompt)
                    async let negativeResponseTask = AIServiceManager.shared.generate(prompt: negativeSystemPrompt)
                    async let alternativeResponseTask = AIServiceManager.shared.generate(prompt: alternativeSystemPrompt)
                    
                    let fullResponse = try await mainResponseTask
                    let negativeResponseRaw = try await negativeResponseTask
                    let alternativeResponseRaw = try await alternativeResponseTask
                    
                    let negativeResponse = negativeResponseRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let alternativeResponse = alternativeResponseRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    
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
                                    if self.alternatives.isEmpty {
                                        self.alternatives.append(alternativeResponse)
                                    } else {
                                        self.alternatives[0] = alternativeResponse
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

    func autoCategorizePrompt(preferences: PreferencesManager, promptService: PromptService) {
        guard preferences.isPremiumActive else {
            showingPremiumFor = "ai_magic"
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else { return }
        
        isCategorizing = true
        
        let availableFolders = promptService.folders.map { $0.name }
        if availableFolders.isEmpty {
            isCategorizing = false
            return
        }
        
        let categoriesStr = availableFolders.joined(separator: ", ")
        let systemPrompt = \"\"\"
        You are an AI assistant. I have the following prompt:
        TITLE: \\(trimmedTitle)
        CONTENT: \\(trimmedContent)
        
        And I have these existing categories: [\\(categoriesStr)]
        
        Which of those categories BEST fits the prompt?
        Reply ONLY with the exact category name. If none fit well, reply with "NONE". Do not include any other text.
        \"\"\"
        
        Task {
            do {
                let fullResponse = try await AIServiceManager.shared.generate(prompt: systemPrompt)
                await MainActor.run {
                    self.isCategorizing = false
                    let result = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if result != "NONE" && availableFolders.contains(result) {
                        withAnimation(.spring()) {
                            self.selectedFolder = result
                        }
                        HapticService.shared.playSuccess()
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
"""

content = content.replace("private var draftHash: Int = 0", new_states + "\n    private var draftHash: Int = 0")
content = content.replace("func updateDraftHash()", new_methods + "\n    func updateDraftHash()")
content = enum_def + "\n" + content

with open(path, "w") as f:
    f.write(content)
