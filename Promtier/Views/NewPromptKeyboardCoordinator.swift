import AppKit
import Combine
import Foundation

@MainActor
final class NewPromptKeyboardCoordinator: ObservableObject {
    private var localMonitor: Any?

    func start(handler: @escaping (NSEvent) -> Bool) {
        guard localMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event) ? nil : event
        }
    }

    func stop() {
        guard let monitor = localMonitor else { return }
        NSEvent.removeMonitor(monitor)
        localMonitor = nil
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
