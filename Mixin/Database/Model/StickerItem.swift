import Foundation
import WCDBSwift
import SDWebImage

struct StickerItem: TableCodable, BaseCodable {
    
    static var tableName: String = "stickers"
    
    let stickerId: String
    let name: String
    let assetUrl: String
    let assetType: String
    let assetWidth: Int
    let assetHeight: Int
    var lastUseAt: String?
    
    let category: String?
    
    var shouldCachePersistently: Bool {
        return shouldCacheStickerWithCategoryPersistently(category: category)
    }
    
    var imageLoadContext: [SDWebImageContextOption: Any]? {
        return stickerLoadContext(persistent: shouldCachePersistently)
    }
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerItem
        static var objectRelationalMapping = TableBinding(CodingKeys.self)
        
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

@inlinable func shouldCacheStickerWithCategoryPersistently(category: String?) -> Bool {
    if let category = category {
        return !category.isEmpty
    } else {
        return false
    }
}

func stickerLoadContext(persistent: Bool) -> [SDWebImageContextOption: Any]? {
    return persistent ? persistentStickerContext : nil
}

func stickerLoadContext(category: String?) -> [SDWebImageContextOption: Any]? {
    let persistent = shouldCacheStickerWithCategoryPersistently(category: category)
    return stickerLoadContext(persistent: persistent)
}
