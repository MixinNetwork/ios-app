import Foundation
import SDWebImage

public enum StickerPrefetcher {
    
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
        let persistentUrls = stickers
            .filter({ $0.shouldCachePersistently })
            .map({ $0.assetUrl })
            .compactMap(URL.init)
        let purgableUrls = stickers
            .filter({ !$0.shouldCachePersistently })
            .map({ $0.assetUrl })
            .compactMap(URL.init)
        persistent.prefetchURLs(persistentUrls)
        purgable.prefetchURLs(purgableUrls)
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
