import Foundation
let path = "Promtier/Views/NewPromptView.swift"
let content = try String(contentsOfFile: path, encoding: .utf8)
var lines = content.components(separatedBy: .newlines)
let startIdx = lines.firstIndex { $0.hasPrefix("struct EditorCard: View {") }
if let s = startIdx {
    var endIdx = s
    var braceCount = 0
    for i in s..<lines.count {
        braceCount += lines[i].components(separatedBy: "{").count - 1
        braceCount -= lines[i].components(separatedBy: "}").count - 1
        if braceCount == 0 { endIdx = i; break }
    }
    lines.removeSubrange(s...endIdx)
    try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    print("Deleted EditorCard")
}
