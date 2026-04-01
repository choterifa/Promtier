import AppKit
import SwiftUI

struct DownsampledImageView: View {
    let imageData: Data
    let cacheKey: String
    let maxPixelSize: Int
    var contentMode: ContentMode = .fill

    @State private var decoded: NSImage? = nil

    var body: some View {
        Group {
            if let decoded {
                Image(nsImage: decoded)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.06))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                            .opacity(0.85)
                    }
            }
        }
        .task(id: cacheKey) {
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
        if decoded != nil { return }
        if let cached = ImageDecodeCache.shared.cachedImage(forKey: cacheKey) {
            decoded = cached
            return
        }

        let dataCopy = imageData
        let maxPixel = maxPixelSize
        let key = cacheKey
        let image = await ImageDecodeThrottler.downsample(data: dataCopy, maxPixelSize: maxPixel)

        guard let image else { return }

        let cost = max(image.size.width, image.size.height)
        ImageDecodeCache.shared.store(image, forKey: key, cost: Int(cost * cost))
        decoded = image
    }
}
