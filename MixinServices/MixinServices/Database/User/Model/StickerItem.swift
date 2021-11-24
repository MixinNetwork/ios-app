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
        return shouldCacheStickerPersistently(stickerId: stickerId)
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stickerId = try container.decode(String.self, forKey: .stickerId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        assetUrl = try container.decodeIfPresent(String.self, forKey: .assetUrl) ?? ""
        assetType = try container.decodeIfPresent(String.self, forKey: .assetType) ?? ""
        assetWidth = try container.decodeIfPresent(Int.self, forKey: .assetWidth) ?? 0
        assetHeight = try container.decodeIfPresent(Int.self, forKey: .assetHeight) ?? 0
        lastUseAt = try container.decodeIfPresent(String.self, forKey: .lastUseAt)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }
    
}

extension StickerItem {
    
    public var assetTypeIsJSON: Bool {
        assetType.uppercased() == "JSON"
    }
    
}

@inlinable public func shouldCacheStickerPersistently(stickerId: String?) -> Bool {
    let stickerIds = AppGroupUserDefaults.User.favoriteAlbumStickers
    if stickerIds.isEmpty {
        return false
    } else {
        return stickerIds.contains(where: { $0 == stickerId })
    }
}

public func stickerLoadContext(persistent: Bool) -> [SDWebImageContextOption: Any]? {
    return persistent ? persistentStickerContext : nil
}

public func stickerLoadContext(stickerId: String?) -> [SDWebImageContextOption: Any]? {
    let persistent = shouldCacheStickerPersistently(stickerId: stickerId)
    return stickerLoadContext(persistent: persistent)
}
