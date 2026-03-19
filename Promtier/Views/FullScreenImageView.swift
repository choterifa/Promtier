import SwiftUI

struct FullScreenImageView: View {
    enum ImageSource: Equatable {
        case data(Data)
        case url(URL)
    }

    let source: ImageSource
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var preferences = PreferencesManager.shared

    @State private var decodedImage: NSImage? = nil
    @State private var isEntering: Bool = false
    @State private var scrimOpacity: Double = 0.0
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isInteracting: Bool = false
    // Controls whether the toolbar auto-hides (after user interaction)
    @State private var toolbarOpacity: Double = 1.0
    @State private var hideTimer: DispatchWorkItem? = nil
    
    // Hint animation states
    @State private var hintOpacity: Double = 0.0
    @State private var hintScale: CGFloat = 0.5
    @State private var hintPulse = false
    @State private var activeHint: HintType = .doubleTap
    
    enum HintType {
        case doubleTap
        case pinch
    }
    
    // Persistent counter to alternate hints (stored in AppStorage for simplicity across sessions)
    @AppStorage("lastHintType") private var lastHintWasPinch = false
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    private func zoomWithAnimation(_ animation: Animation? = .spring(response: 0.35, dampingFraction: 0.8), _ body: @escaping () -> Void) {
        if preferences.disableImageAnimations {
            body()
        } else {
            withAnimation(animation) {
                body()
            }
        }
    }

    private func presentWithAnimation(_ body: @escaping () -> Void) {
        if preferences.disableImageAnimations {
            body()
        } else {
            // Sensación tipo popover de macOS: entrada rápida con rebote sutil
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 24)) {
                body()
            }
        }
    }
    
    init(imageData: Data) {
        self.source = .data(imageData)
    }

    init(imageURL: URL) {
        self.source = .url(imageURL)
    }

    var body: some View {
        ZStack {
            // Base background (match popover/window to avoid white/black flash)
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            // Black scrim fades in after presentation to avoid a light-mode flash
            Color.black
                .opacity(scrimOpacity)
                .ignoresSafeArea()

            contentLayer
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
            if decodedImage == nil {
                Task {
                    // Evita decode sync en main + limita concurrencia global de decodes.
                    let img: NSImage?
                    switch source {
                    case .data(let data):
                        img = await ImageDecodeThrottler.downsample(data: data, maxPixelSize: 2800)
                    case .url(let url):
                        img = await ImageDecodeThrottler.downsample(url: url, maxPixelSize: 2800)
                    }
                    decodedImage = img
                }
            }
            if preferences.disableImageAnimations {
                scrimOpacity = 1.0
                isEntering = true
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    scrimOpacity = 1.0
                }
                presentWithAnimation {
                    isEntering = true
                }
            }
            scheduleHide()
            showGesturesHint()
        }
        .onDisappear {
            isEntering = false
            scrimOpacity = 0.0
        }
    }

    private var contentLayer: some View {
        ZStack {
            // IMAGE LAYER (Isolated to prevent layout shifts)
            ZStack {
                if let nsImage = decodedImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale, anchor: .center)
                        .offset(offset)
                        .animation(isInteracting ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: scale)
                        .animation(isInteracting ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: offset)
                        // PINCH TO ZOOM via MagnificationGesture
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    isInteracting = true
                                    let delta = value / lastScale
                                    lastScale = value
                                    let newScale = (scale * delta).clamped(to: minScale...maxScale)
                                    scale = newScale
                                    bumpToolbar()
                                }
                                .onEnded { _ in
                                    isInteracting = false
                                    lastScale = 1.0
                                    if scale <= minScale {
                                        zoomWithAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                                    isInteracting = true
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    bumpToolbar()
                                }
                                .onEnded { _ in
                                    isInteracting = false
                                    lastOffset = offset
                                    scheduleHide()
                                }
                        )
                        // DOUBLE TAP: toggle between 100% and 200%
                        .onTapGesture(count: 2) {
                            zoomWithAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Removed transaction { $0.animation = nil } to allow explicit zooming animations
            
            // UI CONTROLS LAYER
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
        .opacity(isEntering ? 1.0 : 0.0)
        .scaleEffect(isEntering ? 1.0 : 0.94)
        .offset(y: isEntering ? 0 : 16)
        .overlay {
            // DOUBLE-TAP & PINCH HINT OVERLAY (Non-intrusive)
            if hintOpacity > 0 && !preferences.disableImageAnimations {
                ZStack {
                    if activeHint == .doubleTap {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .scaleEffect(hintPulse ? 1.2 : 0.8)
                            
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                        }
                    } else {
                        ZStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 30, height: 30)
                                    .shadow(radius: 5)
                                    .offset(x: hintPulse ? -40 : -10, y: hintPulse ? 40 : 10)
                                
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 30, height: 30)
                                    .shadow(radius: 5)
                                    .offset(x: hintPulse ? 40 : 10, y: hintPulse ? -40 : -10)
                            }
                            
                            Image(systemName: "arrow.up.right.and.arrow.down.left")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(hintPulse ? 1.0 : 0.5)
                        }
                    }
                }
                .opacity(hintOpacity)
                .scaleEffect(hintScale)
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Hint Logic
    
    private func showGesturesHint() {
        // Toggle the active hint for this opening
        activeHint = lastHintWasPinch ? .doubleTap : .pinch
        lastHintWasPinch.toggle()
        
        // Trigger the hint animation sequence
        withAnimation(.easeIn(duration: 0.3)) {
            hintOpacity = 0.7
            hintScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true)) {
            hintPulse = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                hintOpacity = 0.0
                hintScale = 1.2
            }
        }
    }
    
    // MARK: - Zoom Bar (always rendered, opacity-driven)
    
    private var zoomBar: some View {
        HStack(spacing: 0) {
            // Zoom Out
            Button(action: {
                zoomWithAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
                zoomWithAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
                zoomWithAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
