import Foundation
import SDWebImage

public enum StickerPrefetcher {
    
    private static var prefetchTokens: [String: SDWebImagePrefetchToken] = [:]
    
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
    
    public static func prefetch(stickers: [StickerItem], albumId: String? = nil) {
        let purgableUrls = stickers
            .filter(\.shouldCachePersistently)
            .map(\.assetUrl)
            .compactMap(URL.init)
        let persistentUrls = stickers
            .filter(\.shouldCachePersistently)
            .map(\.assetUrl)
            .compactMap(URL.init)
        purgable.prefetchURLs(purgableUrls)
        if let token = persistent.prefetchURLs(persistentUrls), let albumId = albumId {
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
