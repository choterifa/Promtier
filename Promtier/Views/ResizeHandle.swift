import SwiftUI
import AppKit

struct ResizeHandle: View {
    @EnvironmentObject var preferences: PreferencesManager
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NativeResizeHandle(preferences: preferences)
                .frame(width: 20, height: 20)
                // Ícono visual: solo 3 líneas diagonales sutiles
                .overlay(
                    Canvas { context, size in
                        for i in 0..<3 {
                            let offset = CGFloat(i) * 4
                            var path = Path()
                            path.move(to: CGPoint(x: size.width - 2 - offset, y: size.height - 2))
                            path.addLine(to: CGPoint(x: size.width - 2, y: size.height - 2 - offset))
                            context.stroke(
                                path,
                                with: .color(.secondary.opacity(0.5)),
                                lineWidth: 1.5
                            )
                        }
                    }
                    .allowsHitTesting(false)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

// MARK: - Native Resize Handle
struct NativeResizeHandle: NSViewRepresentable {
    let preferences: PreferencesManager
    
    func makeNSView(context: Context) -> ResizeTrackingView {
        let view = ResizeTrackingView()
        view.preferences = preferences
        return view
    }
    
    func updateNSView(_ nsView: ResizeTrackingView, context: Context) {
        nsView.preferences = preferences
    }
}

class ResizeTrackingView: NSView {
    weak var preferences: PreferencesManager?
    
    private var trackingArea: NSTrackingArea?
    private var isDragging = false
    private var hasPushedCursor = false
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if !hasPushedCursor {
            NSCursor.crosshair.push()
            hasPushedCursor = true
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if !isDragging && hasPushedCursor {
            NSCursor.pop()
            hasPushedCursor = false
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        HapticService.shared.playLight()
        
        if let preferences = preferences {
            preferences.isResizingVisible = true
            preferences.previewWidth = preferences.windowWidth
            preferences.previewHeight = preferences.windowHeight
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let preferences = preferences else { return }
        
        let deltaX = event.deltaX
        let deltaY = event.deltaY
        
        let newWidth  = min(900, max(500, preferences.previewWidth + deltaX))
        let newHeight = min(750, max(450, preferences.previewHeight + deltaY))
        
        let oldW = Int(preferences.previewWidth / 20)
        let newW = Int(newWidth / 20)
        let oldH = Int(preferences.previewHeight / 20)
        let newH = Int(newHeight / 20)
        if oldW != newW || oldH != newH {
            HapticService.shared.playImpact()
        }
        
        preferences.previewWidth = newWidth
        preferences.previewHeight = newHeight
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        
        if let preferences = preferences {
            preferences.isResizingVisible = false
            preferences.windowWidth = preferences.previewWidth
            preferences.windowHeight = preferences.previewHeight
        }
        
        if hasPushedCursor {
            let loc = convert(event.locationInWindow, from: nil)
            if !bounds.contains(loc) {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
        HapticService.shared.playAlignment()
    }
}
