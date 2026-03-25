import Foundation
import AppKit
let attr = try! AttributedString(markdown: "**Bold** and *Italic* and `Code`")
let nsAttr = NSMutableAttributedString(attr)
print(nsAttr.string)
