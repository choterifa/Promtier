import SwiftUI
import AppKit

class FormatMenuPopover {
    static let shared = FormatMenuPopover()
    private var popover: NSPopover?
    private var hideWorkItem: DispatchWorkItem?
    private var lastEditorID: String?

    func show(in view: NSView, at rect: NSRect, editorID: String, themeColor: NSColor) {
        hideWorkItem?.cancel()

        if popover == nil {
            popover = NSPopover()
            popover?.behavior = .transient
            popover?.animates = false
        }

        popover?.contentSize = NSSize(width: 290, height: 54)
        let rootView = AnyView(FloatingFormatBar(editorID: editorID, themeColor: Color(themeColor)))
        if let hostingController = popover?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
        } else {
            popover?.contentViewController = NSHostingController(rootView: rootView)
        }

        if popover?.isShown == true, lastEditorID == editorID {
            popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        } else {
            popover?.close()
            popover?.show(relativeTo: rect, of: view, preferredEdge: .minY)
        }

        lastEditorID = editorID
    }

    func hide() {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.popover?.close()
            self?.lastEditorID = nil
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }
}

struct FloatingFormatBar: View {
    let editorID: String
    let themeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            formatButton(icon: "bold", action: .bold)
            formatButton(icon: "italic", action: .italic)
            formatButton(icon: "strikethrough", action: .strikethrough)
            formatButton(icon: "chevron.left.forwardslash.chevron.right", action: .inlineCode)

            separator

            formatButton(icon: "list.bullet", action: .bulletList)
            formatButton(icon: "list.number", action: .numberedList)

            separator

            formatButton(icon: "increase.indent", action: .indent)
            formatButton(icon: "decrease.indent", action: .outdent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
        )
        .padding(8)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }

    private func formatButton(icon: String, action: PromtierEditorCommandAction) -> some View {
        Button(action: {
            PromtierEditorCommandCenter.post(action, to: editorID)
            HapticService.shared.playLight()
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeColor)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(themeColor.opacity(0.1))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct AIResult: Equatable {
    let result: String
    let range: NSRange
    let id = UUID()
}
