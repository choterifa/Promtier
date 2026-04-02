import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DownsampledImageSlotView: View {
    let imageData: Data
    let slotWidth: CGFloat
    let slotHeight: CGFloat
    let isSelected: Bool
    let tintColor: Color
    let onRemove: () -> Void
    let onPreview: () -> Void
    let onDrop: ([NSItemProvider]) -> Void
    let onDragStart: () -> Void

    @State private var decodedImage: NSImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let decodedImage {
                    Image(nsImage: decodedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.06))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.8)
                                .opacity(0.8)
                        }
                }
            }
            .frame(width: slotWidth, height: slotHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tintColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
            )
            .shadow(color: isSelected ? tintColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPreview)
            .onDrag {
                onDragStart()
                let provider = NSItemProvider(item: imageData as NSData, typeIdentifier: "public.image")
                return provider
            }
            .onDrop(of: [.image], isTargeted: nil) { providers in
                onDrop(providers)
                return true
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
            .help("remove_image".localized(for: PreferencesManager.shared.language))
        }
        .task(id: imageData) {
            await loadDownsampled()
        }
    }

    private func loadDownsampled() async {
        let key = String(imageData.hashValue)
        if let cached = ImageDecodeCache.shared.cachedImage(forKey: key) {
            decodedImage = cached
            return
        }

        if let downsized = await ImageDecodeThrottler.downsample(data: imageData, maxPixelSize: 600) {
            let cost = max(downsized.size.width, downsized.size.height)
            ImageDecodeCache.shared.store(downsized, forKey: key, cost: Int(cost * cost))
            decodedImage = downsized
        }
    }
}
