import Foundation

enum AIAction {
	case enhance, fix, concise, translate, instruct

	var systemPrompt: String {
		switch self {
		case .enhance:
			return "Enhance the following prompt to be more descriptive and effective, keeping the variables {{...}} exactly as they are. Respond ONLY with the improved prompt text."
		case .fix:
			return "Fix grammar and spelling errors in the following prompt, keeping variables {{...}} exactly as they are. Respond ONLY with the corrected text."
		case .concise:
			return "Make the following prompt more concise and direct, keeping variables {{...}} exactly as they are. Respond ONLY with the concise text."
		case .translate:
			let toEnglish = UserDefaults.standard.bool(forKey: "translateToEnglish")
			if toEnglish {
				return "Translate the following text strictly to English. Keep variables {{...}} exactly as they are. Respond ONLY with the translated text."
			}
			let preferredLang = Locale.preferredLanguages.first ?? "es"
			let langName = Locale(identifier: "en_US").localizedString(forIdentifier: preferredLang) ?? "the user's system language"
			return "Translate the following text strictly to \(langName). Keep variables {{...}} exactly as they are. Respond ONLY with the translated text."
		case .instruct:
			return ""
		}
	}
}
