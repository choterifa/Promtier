import AppKit

enum AppInfoCache {
    private static var urlCache: [String: URL] = [:]
    private static var iconCache: [String: NSImage] = [:]
    private static var nameCache: [String: String] = [:]
    private static var notFoundCache: Set<String> = []
    
    private static let lock = NSLock()
    
    static func getURL(for bundleID: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        
        if notFoundCache.contains(bundleID) { return nil }
        if let cached = urlCache[bundleID] { return cached }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            urlCache[bundleID] = url
            return url
        }
        
        notFoundCache.insert(bundleID)
        return nil
    }
    
    static func getIcon(for bundleID: String) -> NSImage? {
        lock.lock()
        let cached = iconCache[bundleID]
        lock.unlock()
        
        if let cached = cached { return cached }
        
        guard let url = getURL(for: bundleID) else { return nil }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Double check after getting the URL outside lock
        if let cached = iconCache[bundleID] { return cached }
        
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = icon
        return icon
    }
    
    static func getName(for bundleID: String) -> String {
        lock.lock()
        let cachedName = nameCache[bundleID]
        lock.unlock()
        
        if let cached = cachedName { return cached }
        
        let url = getURL(for: bundleID)
        let name = url?.deletingPathExtension().lastPathComponent ?? bundleID
        
        lock.lock()
        nameCache[bundleID] = name
        lock.unlock()
        
        return name
    }
}
