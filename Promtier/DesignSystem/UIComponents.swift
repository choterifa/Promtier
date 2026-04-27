//
//  UIComponents.swift
//  Promtier
//
//  Design System: Componentes reutilizables de UI
//

import SwiftUI

// MARK: - Toast Notification (Bottom Slide-In, Auto-Dismiss)

/// Datos inmutables del toast activo. `nil` = oculto.
struct PromtierToastData: Equatable {
    let id: UUID = UUID()          // Identidad única para reiniciar auto-hide
    let icon: String
    let message: String
    let iconColor: Color
    let duration: TimeInterval
    
    static func == (lhs: PromtierToastData, rhs: PromtierToastData) -> Bool {
        lhs.id == rhs.id
    }
}

/// Modifier que renderiza el toast desde abajo y lo auto-descarta.
struct PromtierBottomToastModifier: ViewModifier {
    @Binding var toast: PromtierToastData?
    
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let t = toast {
                HStack(spacing: 8) {
                    Image(systemName: t.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.iconColor)
                    Text(t.message)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(NSColor.windowBackgroundColor))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.97))
                        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: -4)
                )
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(t.id)
                .onAppear {
                    guard t.duration > 0 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + t.duration) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if toast?.id == t.id { toast = nil }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
    }
}

extension View {
    /// Muestra un toast desde la parte inferior que se auto-descarta.
    func promtierBottomToast(_ toast: Binding<PromtierToastData?>) -> some View {
        self.modifier(PromtierBottomToastModifier(toast: toast))
    }
    
    // Backwards-compat alias para código que aún use el API antiguo
    func promtierToast(isPresented: Binding<Bool>, icon: String, message: String, duration: TimeInterval = 2.0, iconColor: Color = .green, autoHide: Bool = true) -> some View {
        self.modifier(PromtierBottomToastModifier(toast: .constant(
            isPresented.wrappedValue ? PromtierToastData(icon: icon, message: message, iconColor: iconColor, duration: duration) : nil
        )))
    }
}

struct PromtierSectionHeader<Trailing: View>: View {
    let iconName: String
    let title: String
    let iconColor: Color
    let bottomPadding: CGFloat
    let trailing: Trailing

    init(
        iconName: String,
        title: String,
        iconColor: Color,
        bottomPadding: CGFloat = 0,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.iconName = iconName
        self.title = title
        self.iconColor = iconColor
        self.bottomPadding = bottomPadding
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Layout.SectionHeader.itemSpacing) {
            Image(systemName: iconName)
                .font(.system(size: Theme.Layout.SectionHeader.iconSize, weight: .bold))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: Theme.Layout.SectionHeader.titleFontSize, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(Theme.Layout.SectionHeader.titleTracking)

            trailing

            Spacer()
        }
        .padding(.horizontal, Theme.Layout.SectionHeader.horizontalPadding)
        .padding(.bottom, bottomPadding)
    }
}

extension PromtierSectionHeader where Trailing == EmptyView {
    init(iconName: String, title: String, iconColor: Color, bottomPadding: CGFloat = 0) {
        self.init(iconName: iconName, title: title, iconColor: iconColor, bottomPadding: bottomPadding) {
            EmptyView()
        }
    }
}
