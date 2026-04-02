import Foundation
import Combine

class TextHoister: ObservableObject {
    var fastText: String
    @Published var slowText: String
    
    private let subject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init(initialText: String = "") {
        self.fastText = initialText
        self.slowText = initialText
        
        subject
            .debounce(for: .seconds(0.15), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                if self?.slowText != text {
                    self?.slowText = text
                }
            }
            .store(in: &cancellables)
    }
    
    func updateFast(_ text: String) {
        self.fastText = text
        self.subject.send(text)
    }
    
    func flush() {
        if slowText != fastText {
            slowText = fastText
        }
    }
    
    func setExternal(_ text: String) {
        self.fastText = text
        self.slowText = text
    }
}
