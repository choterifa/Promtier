import SwiftUI

struct FullScreenImageView: View {
    let imageData: Data
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale *= delta
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            }
            
            // Header con botón de cerrar
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white.opacity(0.7))
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
                
                if scale > 1.0 || offset != .zero {
                    HStack(spacing: 20) {
                        Button(action: {
                            withAnimation(.spring()) {
                                scale = max(1.0, scale - 0.5)
                                if scale == 1.0 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }) {
                            Text("\(Int(scale * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 45)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                scale += 0.5
                            }
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
