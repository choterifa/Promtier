import SwiftUI
import Foundation
import Combine

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct IdentifiableData: Identifiable {
    let id = UUID()
    let value: Data
}

struct AnimatedThinkingText: View {
    let baseText: String

    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let dots = String(repeating: ".", count: dotCount)
        Text("\(baseText)\(dots)")
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
