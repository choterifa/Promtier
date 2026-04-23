import Foundation
import SwiftUI

enum EditorAIUtilities {
    static func isAIAvailable(for preferences: PreferencesManager) -> Bool {
        let useGemini = preferences.geminiEnabled && !preferences.geminiAPIKey.isEmpty
        let useOpenAI = preferences.openAIEnabled && !preferences.openAIApiKey.isEmpty
        return useGemini || useOpenAI
    }

    enum ActionExecutionResult {
        case noProcessableText
        case success(result: AIResult?, responseLength: Int)
        case failure(toastMessage: String, debugMessage: String)
    }

    static func resolveTextProcessingContext(
        primaryText: String,
        plainText: String,
        selectedRange: NSRange?
    ) -> (text: String, range: NSRange)? {
        let sourceText = plainText.isEmpty ? primaryText : plainText
        let fullNSString = sourceText as NSString

        let textToProcess: String
        let rangeToProcess: NSRange

        if let selection = selectedRange, selection.length > 0 {
            textToProcess = fullNSString.substring(with: selection)
            rangeToProcess = selection
        } else {
            textToProcess = sourceText
            rangeToProcess = NSRange(location: 0, length: fullNSString.length)
        }

        guard !textToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return (textToProcess, rangeToProcess)
    }

    static func prompt(for action: AIAction, instruction: String?, text: String) -> String {
        if action == .instruct {
            return "Execute the following instruction/command: \(instruction ?? "")\nRespond ONLY with the result:\n\(text)"
        }
        return "\(action.systemPrompt)\n\nPrompt Fragment:\n\(text)"
    }

    static func executeAction(
        action: AIAction,
        instruction: String?,
        primaryText: String,
        plainText: String,
        selectedRange: NSRange?,
        language: AppLanguage
    ) async -> ActionExecutionResult {
        guard let context = resolveTextProcessingContext(
            primaryText: primaryText,
            plainText: plainText,
            selectedRange: selectedRange
        ) else {
            return .noProcessableText
        }

        let fullPrompt = prompt(for: action, instruction: instruction, text: context.text)

        do {
            let fullResponse = try await AIServiceManager.shared.generate(prompt: fullPrompt)
            let resultString = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if resultString.isEmpty {
                return .success(result: nil, responseLength: fullResponse.count)
            }
            return .success(
                result: AIResult(result: resultString, range: context.range),
                responseLength: fullResponse.count
            )
        } catch {
            return .failure(
                toastMessage: toast(for: error, language: language),
                debugMessage: error.localizedDescription
            )
        }
    }

    @MainActor
    static func beginActionUI(
        language: AppLanguage,
        setIsAIGenerating: (Bool) -> Void,
        setBranchMessage: (String?) -> Void
    ) {
        setIsAIGenerating(true)
        HapticService.shared.playImpact()
        withAnimation {
            setBranchMessage("ai_thinking".localized(for: language))
        }
    }

    @MainActor
    static func applySuccessUI(
        result: AIResult?,
        setBranchMessage: (String?) -> Void,
        setAIResult: (AIResult?) -> Void
    ) {
        withAnimation {
            setBranchMessage(nil)
        }
        HapticService.shared.playSuccess()
        if let result {
            setAIResult(result)
        }
    }

    @MainActor
    static func applyFailureUI(
        toastMessage: String,
        setBranchMessage: @escaping (String?) -> Void,
        getCurrentBranchMessage: @escaping () -> String?,
        clearDelay: TimeInterval = 4.0
    ) {
        HapticService.shared.playError()
        withAnimation {
            setBranchMessage(toastMessage)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay) {
            withAnimation {
                if getCurrentBranchMessage()?.hasPrefix("❌") == true {
                    setBranchMessage(nil)
                }
            }
        }
    }

    static func toast(for error: Error, language: AppLanguage) -> String {
        let base = baseLocalizationKey(for: error).localized(for: language)
        let detail = compactErrorDetail(from: error)
        if detail.isEmpty { return "❌ \(base)" }
        return "❌ \(base)\n\(detail)"
    }

    private static func baseLocalizationKey(for error: Error) -> String {
        let nsError = error as NSError

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
    }

    private static func compactErrorDetail(from error: Error) -> String {
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
}
