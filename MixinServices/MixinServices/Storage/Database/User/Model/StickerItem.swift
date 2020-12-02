import Foundation
import GRDB
import SDWebImage

public struct StickerItem {
    
    public let stickerId: String
    public let name: String
    public let assetUrl: String
    public let assetType: String
    public let assetWidth: Int
    public let assetHeight: Int
    public var lastUseAt: String?
    public let category: String?
    
    public var shouldCachePersistently: Bool {
        return shouldCacheStickerWithCategoryPersistently(category: category)
    }
    
    public var imageLoadContext: [SDWebImageContextOption: Any]? {
        return stickerLoadContext(persistent: shouldCachePersistently)
    }
    
}

extension StickerItem: Codable, DatabaseColumnConvertible, MixinFetchableRecord {

    public enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case lastUseAt = "last_used_at"
        case category
    }
    
}

extension StickerItem {
    
    public var assetTypeIsJSON: Bool {
        assetType.uppercased() == "JSON"
    }
    
}

@inlinable public func shouldCacheStickerWithCategoryPersistently(category: String?) -> Bool {
    if let category = category {
        return !category.isEmpty
    } else {
        return false
    }
}

public func stickerLoadContext(persistent: Bool) -> [SDWebImageContextOption: Any]? {
    return persistent ? persistentStickerContext : nil
}

public func stickerLoadContext(category: String?) -> [SDWebImageContextOption: Any]? {
    let persistent = shouldCacheStickerWithCategoryPersistently(category: category)
    return stickerLoadContext(persistent: persistent)
}
