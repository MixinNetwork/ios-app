import Foundation
import SDWebImage

let localImageManager = SDWebImageManager(cache: SDImageCache.shared, loader: LocalImageLoader())

let localImageContext: [SDWebImageContextOption: Any] = [
    .customManager: localImageManager,
    .storeCacheType: SDImageCacheType.memory.rawValue,
    .originalStoreCacheType: SDImageCacheType.memory.rawValue
]
