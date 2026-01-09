import SwiftUI

/// In-memory image cache with automatic cleanup
actor ImageCache {
    static let shared = ImageCache()

    private var cache: [URL: CachedImage] = [:]
    private let maxCacheSize = 50
    private let maxAge: TimeInterval = 60 // 60 seconds for live thumbnails

    private struct CachedImage {
        let image: Image
        let timestamp: Date
    }

    func image(for url: URL) -> Image? {
        guard let cached = cache[url] else { return nil }

        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > maxAge {
            cache.removeValue(forKey: url)
            return nil
        }

        return cached.image
    }

    func store(_ image: Image, for url: URL) {
        // Cleanup old entries if cache is full
        if cache.count >= maxCacheSize {
            let cutoff = Date().addingTimeInterval(-maxAge)
            cache = cache.filter { $0.value.timestamp > cutoff }

            // If still full, remove oldest
            if cache.count >= maxCacheSize {
                let oldest = cache.min { $0.value.timestamp < $1.value.timestamp }
                if let key = oldest?.key {
                    cache.removeValue(forKey: key)
                }
            }
        }

        cache[url] = CachedImage(image: image, timestamp: Date())
    }

    func clearAll() {
        cache.removeAll()
    }
}

/// Cached async image view
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: Image?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = loadedImage {
                content(image)
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        isLoading = true

        // Check cache first
        if let cached = await ImageCache.shared.image(for: url) {
            loadedImage = cached
            isLoading = false
            return
        }

        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let nsImage = NSImage(data: data) {
                let image = Image(nsImage: nsImage)
                await ImageCache.shared.store(image, for: url)
                await MainActor.run {
                    loadedImage = image
                }
            }
        } catch {
            // Silently fail - placeholder will show
        }

        isLoading = false
    }
}
