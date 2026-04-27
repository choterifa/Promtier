import SwiftUI

struct CopiarButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 10))
                Text("copy".localized(for: PreferencesManager.shared.language))
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.85) : Color.blue) : Color.gray.opacity(0.3))
                    .shadow(color: isEnabled && isHovered ? Color.blue.opacity(0.4) : (isEnabled ? Color.blue.opacity(0.2) : .clear), radius: isHovered ? 12 : 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct SendDraftButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.9) : Color.blue) : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .offset(x: 1, y: -1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CancelDraftButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.red.opacity(0.9) : Color.red.opacity(0.8))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct QuickDraftActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isEnabled ? (isHovered ? Color.blue.opacity(0.12) : Color.primary.opacity(0.06)) : Color.primary.opacity(0.03))
                    .overlay(
                        Capsule()
                            .stroke(isEnabled ? (isHovered ? Color.blue.opacity(0.4) : Color.primary.opacity(0.1)) : Color.primary.opacity(0.05), lineWidth: 1)
                    )
            )
            .foregroundColor(isEnabled ? (isHovered ? .blue : .primary) : .secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
