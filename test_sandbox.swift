import Foundation
if let _ = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] {
    print("Sandboxed")
} else {
    print("Not Sandboxed")
}
