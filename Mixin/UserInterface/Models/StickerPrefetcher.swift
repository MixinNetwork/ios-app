import Foundation
import SDWebImage
import YYImage

enum StickerPrefetcher {
    
    static let persistentPrefetcher: SDWebImagePrefetcher = {
        let prefetcher = SDWebImagePrefetcher(imageManager: .persistentSticker)
        prefetcher.animatedImageClass = YYImage.self
        return prefetcher
    }()
    static let purgablePrefetcher: SDWebImagePrefetcher = {
        let prefetcher = SDWebImagePrefetcher(imageManager: .shared)
        prefetcher.animatedImageClass = YYImage.self
        return prefetcher
    }()
    
    static func prefetch(stickers: [StickerItem]) {
        let persistentUrls = stickers
            .filter({ $0.shouldCachePersistently })
            .map({ $0.assetUrl })
            .compactMap(URL.init)
        let purgableUrls = stickers
            .filter({ !$0.shouldCachePersistently })
            .map({ $0.assetUrl })
            .compactMap(URL.init)
        persistentPrefetcher.prefetchURLs(persistentUrls)
        purgablePrefetcher.prefetchURLs(purgableUrls)
    }
    
}

fileprivate extension SDWebImagePrefetcher {
    
    var animatedImageClass: UIImage.Type? {
        get {
            return context?[.animatedImageClass] as? UIImage.Type
        }
        set {
            var newContext = context ?? [:]
            newContext[.animatedImageClass] = YYImage.self
            context = newContext
        }
    }
    
}
