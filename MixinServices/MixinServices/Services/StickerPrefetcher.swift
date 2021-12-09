import Foundation
import SDWebImage

public enum StickerPrefetcher {
    
    private static var prefetchTokens = SafeDictionary<String, SDWebImagePrefetchToken>()
    
    public static let persistent: SDWebImagePrefetcher = {
        let prefetcher = SDWebImagePrefetcher(imageManager: .persistentSticker)
        prefetcher.animatedImageClass = SDAnimatedImage.self
        return prefetcher
    }()
    public static let purgable: SDWebImagePrefetcher = {
        let prefetcher = SDWebImagePrefetcher(imageManager: .shared)
        prefetcher.animatedImageClass = SDAnimatedImage.self
        return prefetcher
    }()
    
    public static func prefetch(stickers: [StickerItem]) {
        let purgableUrls = stickers
            .filter({ !$0.shouldCachePersistently })
            .map(\.assetUrl)
            .compactMap(URL.init)
        let persistentUrls = stickers
            .filter(\.shouldCachePersistently)
            .map(\.assetUrl)
            .compactMap(URL.init)
        purgable.prefetchURLs(purgableUrls)
        persistent.prefetchURLs(persistentUrls)
    }
    
    public static func prefetchPersistently(urls: [URL], albumId: String) {
        guard !urls.isEmpty else {
            return
        }
        if let token = persistent.prefetchURLs(urls) {
            prefetchTokens[albumId] = token
        }
    }
    
    public static func cancelPrefetching(albumId: String) {
        if let token = prefetchTokens[albumId] {
            token.cancel()
            prefetchTokens.removeValue(forKey: albumId)
        }
    }
    
}

public extension SDWebImagePrefetcher {
    
    var animatedImageClass: UIImage.Type? {
        get {
            return context?[.animatedImageClass] as? UIImage.Type
        }
        set {
            var newContext = context ?? [:]
            newContext[.animatedImageClass] = SDAnimatedImage.self
            context = newContext
        }
    }
    
}
