import SwiftUI
import AppKit

struct TextEditorDropDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            var parent = view.superview
            while parent != nil {
                if let textView = parent as? NSTextView {
                    textView.unregisterDraggedTypes()
                    break
                }
                if let scrollView = parent as? NSScrollView, let textView = scrollView.documentView as? NSTextView {
                    textView.unregisterDraggedTypes()
                    break
                }
                parent = parent?.superview
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func disableNativeDrop() -> some View {
        self.background(TextEditorDropDisabler())
    }
}
