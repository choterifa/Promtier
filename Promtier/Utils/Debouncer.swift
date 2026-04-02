import Foundation
import Combine

class Debouncer: ObservableObject {
    @Published var debouncedValue: String = ""
    private var valueSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(delay: TimeInterval = 0.15) {
        valueSubject
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .assign(to: &$debouncedValue)
    }

    func send(_ value: String) {
        valueSubject.send(value)
    }
}
