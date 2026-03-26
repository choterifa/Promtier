import Foundation

let val: NSNumber? = NSNumber(value: 1)
let isStrikethrough = val?.intValue ?? 0 > 0
print(isStrikethrough)
