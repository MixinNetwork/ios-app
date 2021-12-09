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
    public let isAdded: Bool?
    
    public var shouldCachePersistently: Bool {
        return isAdded ?? false
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
        case isAdded = "added"
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
        isAdded = try container.decode(Bool.self, forKey: .isAdded)
    }
    
}

extension StickerItem {
    
    public var assetTypeIsJSON: Bool {
        assetType.uppercased() == "JSON"
    }
    
}

public func stickerLoadContext(persistent: Bool?) -> [SDWebImageContextOption: Any]? {
    return (persistent ?? false) ? persistentStickerContext : nil
}
