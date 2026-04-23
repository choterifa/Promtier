//
//  TrackpadSwipeModifier.swift
//  Promtier
//
//  Detecta swipes horizontales del trackpad en macOS interceptando scrollWheel.
//
//  CÓMO FUNCIONA:
//  scrollWheel en macOS se enruta así:
//    1. El evento va al NSView bajo el cursor (según hitTest del window).
//    2. Si ese view no lo maneja (llama super), sube por el responder chain.
//    3. Eventualmente llega al NSScrollView que mueve el contenido.
//
//  Nuestra estrategia:
//  - Usamos un NSViewRepresentable visible (frame real, no cero) que SÍ participa
//    en hit testing para poder recibir scrollWheel.
//  - Pero no interceptamos mouseDown/Up/Moved, así que los clics de SwiftUI
//    funcionan normalmente (SwiftUI usa sus propios NSClickGestureRecognizer).
//  - Si el scroll es horizontal → lo consumimos (no llamamos super).
//  - Si el scroll es vertical → llamamos super para que llegue al ScrollView.
//

import SwiftUI
import AppKit

// MARK: - Public API

extension View {
    /// Detecta un swipe horizontal del trackpad (dos dedos) en macOS.
    /// El scroll vertical sigue funcionando normalmente.
    ///
    /// - Parameters:
    ///   - enabled: Si `false`, el detector queda inactivo.
    ///   - onChanged: Delta X acumulado (negativo = swipe a la izquierda).
    ///   - onEnded: Delta X total y velocidad estimada al terminar el gesto.
    func trackpadHorizontalSwipe(
        enabled: Bool = true,
        onChanged: @escaping (_ deltaX: CGFloat) -> Void,
        onEnded: @escaping (_ totalDeltaX: CGFloat, _ velocityX: CGFloat) -> Void
    ) -> some View {
        self.overlay(
            SwipeDetectorRepresentable(
                enabled: enabled,
                onChanged: onChanged,
                onEnded: onEnded
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

// MARK: - NSViewRepresentable

private struct SwipeDetectorRepresentable: NSViewRepresentable {
    let enabled: Bool
    let onChanged: (_ deltaX: CGFloat) -> Void
    let onEnded: (_ totalDeltaX: CGFloat, _ velocityX: CGFloat) -> Void

    func makeCoordinator() -> SwipeCoordinator {
        SwipeCoordinator()
    }

    func makeNSView(context: Context) -> SwipeDetectorNSView {
        let view = SwipeDetectorNSView()
        view.coordinator = context.coordinator
        view.isEnabled = enabled
        return view
    }

    func updateNSView(_ nsView: SwipeDetectorNSView, context: Context) {
        nsView.isEnabled = enabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }
}

// MARK: - Coordinator

final class SwipeCoordinator {
    var onChanged: ((_ deltaX: CGFloat) -> Void)?
    var onEnded: ((_ totalDeltaX: CGFloat, _ velocityX: CGFloat) -> Void)?
}

// MARK: - NSView principal

final class SwipeDetectorNSView: NSView {

    var coordinator: SwipeCoordinator?
    var isEnabled: Bool = true

    private var accumulatedDeltaX: CGFloat = 0
    private var isTrackingHorizontal: Bool = false
    private var gestureActive: Bool = false

    // ------------------------------------------------------------------
    // IMPORTANTE: Participar en hit testing para recibir scrollWheel.
    // Forwarding de mouse events al siguiente respondedor para no bloquear
    // los NSClickGestureRecognizer de SwiftUI.
    // ------------------------------------------------------------------
    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }
    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    // scrollWheel se enruta al view más profundo bajo el cursor.
    // Al ser un overlay con frame completo, seremos ese view.
    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else {
            super.scrollWheel(with: event)
            return
        }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY

        switch event.phase {

        case .began:
            accumulatedDeltaX = 0
            isTrackingHorizontal = false
            gestureActive = true

        case .changed:
            guard gestureActive else {
                super.scrollWheel(with: event)
                return
            }
            accumulatedDeltaX += dx

            if !isTrackingHorizontal {
                let absX = abs(accumulatedDeltaX)
                if absX < 3 {
                    // Señal muy pequeña aún, seguir acumulando sin decidir
                    super.scrollWheel(with: event)
                    return
                }
                if absX > abs(dy) * 2 {
                    // Claramente horizontal → activar swipe
                    isTrackingHorizontal = true
                } else {
                    // Claramente vertical → ceder al ScrollView
                    gestureActive = false
                    super.scrollWheel(with: event)
                    return
                }
            }

            // Consumir el evento (no llamar super) para que el ScrollView no scrollee
            let delta = accumulatedDeltaX
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.onChanged?(delta)
            }

        case .ended:
            guard gestureActive else {
                super.scrollWheel(with: event)
                return
            }

            if isTrackingHorizontal {
                let total = accumulatedDeltaX
                let velocity = dx * 60
                DispatchQueue.main.async { [weak self] in
                    self?.coordinator?.onEnded?(total, velocity)
                }
            } else {
                super.scrollWheel(with: event)
            }
            reset()

        case .cancelled:
            if !isTrackingHorizontal { super.scrollWheel(with: event) }
            reset()

        default:
            super.scrollWheel(with: event)
        }
    }

    private func reset() {
        accumulatedDeltaX = 0
        isTrackingHorizontal = false
        gestureActive = false
    }
}
