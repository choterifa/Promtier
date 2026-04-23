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
    
    static func generateCategoryIconAndColorPrompt(categoryName: String) -> String {
        let validIcons = IconPickerView.allIconNames
        let iconListString = validIcons.joined(separator: ", ")
        
        return """
        You are an expert UI designer. Based on the category name '\(categoryName)', suggest:
        1. The most appropriate SF Symbol icon from ONLY this exact list: [\(iconListString)]. You MUST choose from this list. Do NOT invent icon names.
        2. A fitting, vibrant hex color code (e.g., #FF5733) that matches the semantic meaning of the category.

        Respond ONLY with valid JSON in the following format, with NO markdown formatting, NO markdown code blocks (like ```json), and NO additional text:
        {
            "icon": "selected.icon.name",
            "color": "#HEXCOLOR"
        }
        """
    }
}
