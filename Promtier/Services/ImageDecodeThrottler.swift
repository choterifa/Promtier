import AppKit
import Foundation

actor ImageDecodeSemaphore {
    private let maxPermits: Int
    private var inUse: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxPermits: Int) {
        self.maxPermits = max(1, maxPermits)
    }

    func acquire() async {
        if inUse < maxPermits {
            inUse += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        // El permiso se transfiere desde `release()`; no incrementamos aquí.
    }

    func release() {
        if !waiters.isEmpty {
            let next = waiters.removeFirst()
            next.resume()
            return
        }
        inUse = max(0, inUse - 1)
    }
}

enum ImageDecodeThrottler {
    // CONFIGURABLE: 2 evita saturar I/O y decode al abrir previews con varias imágenes.
    private static let semaphore = ImageDecodeSemaphore(maxPermits: 2)

    static func downsample(url: URL, maxPixelSize: Int) async -> NSImage? {
        await semaphore.acquire()
        let image = await Task.detached(priority: .userInitiated) {
            ImageDecodeCache.shared.downsampledImage(from: url, maxPixelSize: maxPixelSize)
        }.value
        await semaphore.release()
        return image
    }

    static func downsample(data: Data, maxPixelSize: Int) async -> NSImage? {
        await semaphore.acquire()
        let image = await Task.detached(priority: .userInitiated) {
            ImageDecodeCache.shared.downsampledImage(from: data, maxPixelSize: maxPixelSize)
        }.value
        await semaphore.release()
        return image
    }

    static func prewarm(url: URL, cacheKey: String, maxPixelSize: Int) async {
        if ImageDecodeCache.shared.cachedImage(forKey: cacheKey) != nil { return }
        guard let image = await downsample(url: url, maxPixelSize: maxPixelSize) else { return }
        let cost = max(image.size.width, image.size.height)
        ImageDecodeCache.shared.store(image, forKey: cacheKey, cost: Int(cost * cost))
    }
}

