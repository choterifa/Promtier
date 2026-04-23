import Foundation

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let value: URL
}

