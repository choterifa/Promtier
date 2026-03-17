import SwiftUI

struct FullScreenImageView: View {
    let imageData: Data
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    // Controls whether the toolbar auto-hides (after user interaction)
    @State private var toolbarOpacity: Double = 1.0
    @State private var hideTimer: DispatchWorkItem? = nil
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale, anchor: .center)
                    .offset(offset)
                    // PINCH TO ZOOM via MagnificationGesture
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = (scale * delta).clamped(to: minScale...maxScale)
                                scale = newScale
                                bumpToolbar()
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale <= minScale {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        scale = minScale
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                                scheduleHide()
                            }
                    )
                    // PAN (only when zoomed in)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                bumpToolbar()
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                scheduleHide()
                            }
                    )
                    // DOUBLE TAP: toggle between 100% and 200%
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if scale > minScale {
                                scale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                        bumpToolbar()
                        scheduleHide()
                    }
            }
            
            // CLOSE BUTTON (always visible)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
                Spacer()

                // ZOOM TOOLBAR (always shown, auto-dims after inactivity)
                zoomBar
                    .opacity(toolbarOpacity)
                    .animation(.easeInOut(duration: 0.35), value: toolbarOpacity)
                    .padding(.bottom, 28)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onHover { isHovering in
            if isHovering {
                bumpToolbar()
            } else {
                scheduleHide()
            }
        }
        .onAppear {
            scheduleHide()
        }
    }
    
    // MARK: - Zoom Bar (always rendered, opacity-driven)
    
    private var zoomBar: some View {
        HStack(spacing: 0) {
            // Zoom Out
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    scale = max(minScale, scale - 0.5)
                    if scale <= minScale {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                bumpToolbar()
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Alejar")

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.3))

            // Percentage tap-to-reset
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    scale = minScale
                    offset = .zero
                    lastOffset = .zero
                }
                bumpToolbar()
            }) {
                Text("\(Int(scale * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(width: 52, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Restablecer zoom")

            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.3))

            // Zoom In
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    scale = min(maxScale, scale + 0.5)
                }
                bumpToolbar()
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Acercar")
        }
        .foregroundColor(.white)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.65))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Toolbar visibility helpers

    private func bumpToolbar() {
        hideTimer?.cancel()
        withAnimation { toolbarOpacity = 1.0 }
    }
    
    private func scheduleHide() {
        hideTimer?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                toolbarOpacity = 0.25
            }
        }
        hideTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }
}

// MARK: - Clamp helper
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
