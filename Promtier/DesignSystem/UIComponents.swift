//
//  UIComponents.swift
//  Promtier
//
//  Design System: Componentes reutilizables de UI
//

import SwiftUI

// MARK: - Toast Notification Component
struct PromtierToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let icon: String
    let message: String
    var duration: TimeInterval = 2.0
    var iconColor: Color = .green
    var autoHide: Bool = true
    
    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if isPresented {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                        Text(message)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                    .foregroundColor(Color(NSColor.windowBackgroundColor))
                    .padding(.top, 42)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        if autoHide {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
            },
            alignment: .top
        )
    }
}

extension View {
    func promtierToast(isPresented: Binding<Bool>, icon: String, message: String, duration: TimeInterval = 2.0, iconColor: Color = .green, autoHide: Bool = true) -> some View {
        self.modifier(PromtierToastModifier(isPresented: isPresented, icon: icon, message: message, duration: duration, iconColor: iconColor, autoHide: autoHide))
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
