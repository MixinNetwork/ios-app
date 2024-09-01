import Foundation
import SDWebImage

extension SDWebImageManager {
    
    static let localImage = SDWebImageManager(cache: SDImageCache.shared, loader: LocalImageLoader())
    static let assetIcon = SDWebImageManager(cache: SDImageCache.assetIcon, loader: SDImageLoadersManager.shared)
    static let persistentSticker = SDWebImageManager(cache: SDImageCache.persistentSticker, loader: SDImageLoadersManager.shared)
    static let templateTransforming: SDWebImageManager = {
        let manager = SDWebImageManager(cache: SDImageCache.shared, loader: SDImageLoadersManager.shared)
        manager.transformer = TemplateImageTransformer()
        return manager
    }()
    
}

extension SDImageCacheConfig {
    
    static let persistent: SDImageCacheConfig = {
        let config = SDImageCacheConfig()
        config.maxDiskAge = -1
        return config
    }()
    
}

extension SDImageCache {
    
    public static let persistentSticker = SDImageCache(namespace: "Sticker", diskCacheDirectory: documentPath, config: .persistent)
    
    internal static let assetIcon = SDImageCache(namespace: "AssetIcon", diskCacheDirectory: documentPath, config: .persistent)
    
    private static let documentPath = AppGroupContainer.documentsUrl.path
    
}

final class TemplateImageTransformer: NSObject, SDImageTransformer {
    
    let transformerKey: String = "templated"
    
    func transformedImage(with image: UIImage, forKey key: String) -> UIImage? {
        image.withRenderingMode(.alwaysTemplate)
    }
    
}

public let localImageContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.localImage,
    .storeCacheType: SDImageCacheType.memory.rawValue,
    .originalStoreCacheType: SDImageCacheType.memory.rawValue,
    .imageThumbnailPixelSize: CGSize(width: 8192, height: 8192),
]

public let assetIconContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.assetIcon
]

public let persistentStickerContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.persistentSticker
]

public let templateImageTransformingContext: [SDWebImageContextOption: Any] = [
    .customManager: SDWebImageManager.templateTransforming
]
