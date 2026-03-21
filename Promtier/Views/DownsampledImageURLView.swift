import AppKit
import SwiftUI

struct DownsampledImageURLView: View {
    let imageURL: URL
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
                            .fixedSize()
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

        let url = imageURL
        let maxPixel = maxPixelSize
        let key = cacheKey
        let image = await ImageDecodeThrottler.downsample(url: url, maxPixelSize: maxPixel)

        guard let image else { return }
        let cost = max(image.size.width, image.size.height)
        ImageDecodeCache.shared.store(image, forKey: key, cost: Int(cost * cost))
        decoded = image
    }
}
