import Foundation
import WCDBSwift
import SDWebImage

public struct StickerItem: TableCodable, BaseCodable {
    
    static var tableName: String = "stickers"
    
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
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = StickerItem
        public static var objectRelationalMapping = TableBinding(CodingKeys.self)
        
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
