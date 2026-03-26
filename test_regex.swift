import Foundation

let str1 = "  - hello"
let str2 = "  1. hello"
let str3 = "hello"

print(str1.replacingOccurrences(of: "^(\\s*)[-•]\\s", with: "$1", options: .regularExpression))
print(str2.replacingOccurrences(of: "^(\\s*)\\d+\\.\\s", with: "$1", options: .regularExpression))
