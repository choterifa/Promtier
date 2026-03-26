import Foundation

enum PromtierEditorCommandAction: String {
    case bold
    case italic
    case inlineCode
    case strikethrough
    case bulletList
    case numberedList
    case indent
    case outdent
}

extension Notification.Name {
    static let promtierEditorCommand = Notification.Name("PromtierEditorCommand")
}

enum PromtierEditorCommandCenter {
    static func post(_ action: PromtierEditorCommandAction, to editorID: String) {
        NotificationCenter.default.post(
            name: .promtierEditorCommand,
            object: nil,
            userInfo: [
                "editorID": editorID,
                "action": action.rawValue
            ]
        )
    }
}
