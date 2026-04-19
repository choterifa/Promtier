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
