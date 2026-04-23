import SwiftUI
import UniformTypeIdentifiers

struct ImageSlotView: View {
    let imageData: Data
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let isSelected: Bool
    let tintColor: Color
    let onRemove: () -> Void
    let onPreview: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    let onDragStart: () -> Void

    @State private var isTargeted = false
    @State private var isHovering = false
    @State private var isHoveringRemove = false
    @State private var isFillMode = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: isFillMode ? .fill : .fit)
                    .frame(width: slotWidth, height: slotHeight, alignment: .center)
                    .clipped()
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTargeted || isSelected ? Color.blue.opacity(0.5) : Color.primary.opacity(0.05), lineWidth: (isTargeted || isSelected) ? 2.0 : 1)
                    )
                    .onTapGesture(perform: onPreview)
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(item: imageData as NSData, typeIdentifier: UTType.image.identifier)
                    }
                    .shadow(color: Color.black.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
                    .scaleEffect(isTargeted ? 1.05 : (isHovering ? 1.015 : 1.0))
                    .animation(.spring(response: 0.3), value: isTargeted)
                    .animation(.spring(response: 0.3), value: isHovering)
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFillMode.toggle()
                            }
                        } label: {
                            Image(systemName: isFillMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(isHovering ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                    }
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3)) {
                            isHovering = hovering
                        }
                    }

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(isHoveringRemove ? .white : .primary.opacity(0.6))
                        .padding(5)
                        .background(
                            ZStack {
                                if #available(macOS 12.0, *) {
                                    Circle()
                                        .fill(isHoveringRemove ? tintColor.opacity(0.8) : .clear)
                                        .background(.ultraThinMaterial, in: Circle())
                                } else {
                                    Circle()
                                        .fill(isHoveringRemove ? tintColor.opacity(0.8) : Color.white.opacity(0.6))
                                }
                            }
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 2)
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringRemove = hovering
                    }
                }
            }
        }
        .onDrop(of: [.image, .fileURL, .url], isTargeted: $isTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}
