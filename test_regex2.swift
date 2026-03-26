import Foundation
let str1 = "  hello"
let replaced = str1.replacingOccurrences(of: "^(\\s*)", with: "$1• ", options: .regularExpression)
print("'\(_: replaced)'")
