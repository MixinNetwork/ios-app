import Foundation
import SDWebImage

let localImageManager = SDWebImageManager(cache: SDImageCache.shared, loader: LocalImageLoader())

let localImageContext: [SDWebImageContextOption: Any] = [
    .customManager: localImageManager,
    .storeCacheType: SDImageCacheType.memory.rawValue,
    .originalStoreCacheType: SDImageCacheType.memory.rawValue
]

let documentPath = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?.path

let assetIconCache = SDImageCache(namespace: "AssetIcon", diskCacheDirectory: documentPath)
let assetIconImageManager = SDWebImageManager(cache: assetIconCache, loader: SDImageLoadersManager.shared)
let assetIconContext: [SDWebImageContextOption: Any] = [
    .customManager: assetIconImageManager
]
