import Foundation
import SDWebImage

extension SDWebImageManager {
    
    static let localImage = SDWebImageManager(cache: SDImageCache.shared, loader: LocalImageLoader())
    static let assetIcon = SDWebImageManager(cache: SDImageCache.assetIcon, loader: SDImageLoadersManager.shared)
    static let persistentSticker = SDWebImageManager(cache: SDImageCache.persistentSticker, loader: SDImageLoadersManager.shared)
    
}

extension SDImageCacheConfig {
    
    static let persistent: SDImageCacheConfig = {
        let config = SDImageCacheConfig()
        config.maxDiskAge = -1
        config.diskCacheExpireType = .accessDate
        return config
    }()
    
}

extension SDImageCache {
    
    static let assetIcon = SDImageCache(namespace: "AssetIcon", diskCacheDirectory: documentPath, config: .persistent)
    static let persistentSticker = SDImageCache(namespace: "Sticker", diskCacheDirectory: documentPath, config: .persistent)
    
    private static let documentPath = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?.path
    
}

let localImageContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.localImage,
    .storeCacheType: SDImageCacheType.memory.rawValue,
    .originalStoreCacheType: SDImageCacheType.memory.rawValue
]

let assetIconContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.assetIcon
]

let persistentStickerContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.persistentSticker
]
