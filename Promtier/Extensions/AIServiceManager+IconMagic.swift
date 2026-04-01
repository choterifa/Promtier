import Foundation

extension AIServiceManager {
    static func generateCategoryIconPrompt(categoryName: String) -> String {
        let validIcons = IconPickerView.allIconNames
        let iconListString = validIcons.joined(separator: ", ")
        
        return """
        Based on the category name '\(categoryName)', suggest the most appropriate SF Symbol icon from ONLY this exact list: [\(iconListString)].
        You MUST choose from this list. Do NOT invent icon names.
        Respond ONLY with the SF Symbol name (e.g. terminal.fill). Nothing else.
        """
    }
}
