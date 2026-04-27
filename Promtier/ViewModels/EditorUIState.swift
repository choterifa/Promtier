import SwiftUI
import Combine
import Foundation

final class EditorUIState: ObservableObject {
    @Published var insertionRequest: String?
    @Published var replaceSnippetRequest: String?
    @Published var showSnippets: Bool = false
    @Published var snippetSearchQuery: String = ""
    @Published var snippetSelectedIndex: Int = 0
    @Published var triggerSnippetSelection: Bool = false
    @Published var showVariables: Bool = false
    @Published var variablesSelectedIndex: Int = 0
    @Published var triggerVariablesSelection: Bool = false
    @Published var triggerAIRequest: String?
    @Published var isAIActive: Bool = false
    @Published var selectedRange: NSRange?
    @Published var aiResult: AIResult?
    @Published var activeGeneratingID: String?
}
