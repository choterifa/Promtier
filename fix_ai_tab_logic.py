import sys
import re

try:
    with open('Promtier/Components/AITab.swift', 'r') as f:
        content = f.read()

    # OpenAI menu fix
    openai_menu_old = """                            Menu {
                                Section("Suggested") {
                                    ForEach(OpenAIService.suggestedChatModels, id: \\.self) { model in
                                        Button(model) { preferences.openAIDefaultModel = model }
                                    }
                                }

                                if !openAIAvailableModels.isEmpty {
                                    Section("From your account") {
                                        ForEach(openAIAvailableModels, id: \\.self) { model in
                                            Button(model) { preferences.openAIDefaultModel = model }
                                        }
                                    }
                                }
                            } label:"""
    
    openai_menu_new = """                            Menu {
                                if openAIAvailableModels.isEmpty {
                                    Section("Suggested") {
                                        ForEach(OpenAIService.suggestedChatModels, id: \\.self) { model in
                                            Button(model) { preferences.openAIDefaultModel = model }
                                        }
                                    }
                                } else {
                                    Section("Available Models") {
                                        ForEach(openAIAvailableModels, id: \\.self) { model in
                                            Button(model) { preferences.openAIDefaultModel = model }
                                        }
                                    }
                                }
                            } label:"""

    content = content.replace(openai_menu_old, openai_menu_new)

    # Gemini menu fix
    gemini_menu_old = """                                Menu {
                                    Section("Suggested") {
                                        Button("gemini-2.5-pro") { preferences.geminiDefaultModel = "gemini-2.5-pro" }
                                        Button("gemini-2.5-flash • Recomendado") { preferences.geminiDefaultModel = "gemini-2.5-flash" }
                                        Button("gemini-2.0-pro-exp-02-05") { preferences.geminiDefaultModel = "gemini-2.0-pro-exp-02-05" }
                                        Button("gemini-2.0-flash") { preferences.geminiDefaultModel = "gemini-2.0-flash" }
                                        Button("gemini-2.0-flash-lite") { preferences.geminiDefaultModel = "gemini-2.0-flash-lite" }
                                    }
                                    if !geminiAvailableModels.isEmpty {
                                        Section("From your account") {
                                            ForEach(geminiAvailableModels, id: \\.self) { model in
                                                Button(model) { preferences.geminiDefaultModel = model }
                                            }
                                        }
                                    }
                                } label:"""
                                
    gemini_menu_new = """                                Menu {
                                    if geminiAvailableModels.isEmpty {
                                        Section("Suggested") {
                                            Button("gemini-2.5-pro") { preferences.geminiDefaultModel = "gemini-2.5-pro" }
                                            Button("gemini-2.5-flash • Recomendado") { preferences.geminiDefaultModel = "gemini-2.5-flash" }
                                            Button("gemini-2.0-pro-exp-02-05") { preferences.geminiDefaultModel = "gemini-2.0-pro-exp-02-05" }
                                            Button("gemini-2.0-flash") { preferences.geminiDefaultModel = "gemini-2.0-flash" }
                                            Button("gemini-2.0-flash-lite") { preferences.geminiDefaultModel = "gemini-2.0-flash-lite" }
                                        }
                                    } else {
                                        Section("Available Models") {
                                            ForEach(geminiAvailableModels, id: \\.self) { model in
                                                Button(model) { preferences.geminiDefaultModel = model }
                                            }
                                        }
                                    }
                                } label:"""

    content = content.replace(gemini_menu_old, gemini_menu_new)

    # OpenRouter menu fix
    openrouter_menu_old = """                            Menu {
                                Section("Suggested") {
                                    ForEach(OpenAIService.suggestedChatModels, id: \\.self) { model in
                                        Button(model) { preferences.openRouterDefaultModel = model }
                                    }
                                }
                                if !openRouterAvailableModels.isEmpty {
                                    Section("From your account") {
                                        ForEach(openRouterAvailableModels, id: \\.self) { model in
                                            Button(model) { preferences.openRouterDefaultModel = model }
                                        }
                                    }
                                }
                            } label:"""

    openrouter_menu_new = """                            Menu {
                                if openRouterAvailableModels.isEmpty {
                                    Section("Suggested") {
                                        ForEach(OpenAIService.suggestedChatModels, id: \\.self) { model in
                                            Button(model) { preferences.openRouterDefaultModel = model }
                                        }
                                    }
                                } else {
                                    Section("Available Models") {
                                        // OpenRouter can return 300+ models, Menu handles them natively but we cap them visually or just list them
                                        ForEach(openRouterAvailableModels, id: \\.self) { model in
                                            Button(model) { preferences.openRouterDefaultModel = model }
                                        }
                                    }
                                }
                            } label:"""

    content = content.replace(openrouter_menu_old, openrouter_menu_new)

    with open('Promtier/Components/AITab.swift', 'w') as f:
        f.write(content)

    print("Success")
except Exception as e:
    print(f"Error: {e}")

