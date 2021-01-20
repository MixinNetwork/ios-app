import Foundation
import GRDB

public struct Sticker {
    
    public let stickerId: String
    public let name: String
    public let assetUrl: String
    public let assetType: String
    public let assetWidth: Int
    public let assetHeight: Int
    public var lastUseAt: String?
    
    public init(stickerId: String, name: String, assetUrl: String, assetType: String, assetWidth: Int, assetHeight: Int, lastUseAt: String?) {
        self.stickerId = stickerId
        self.name = name
        self.assetUrl = assetUrl
        self.assetType = assetType
        self.assetWidth = assetWidth
        self.assetHeight = assetHeight
        self.lastUseAt = lastUseAt
    }
    
    public init(response: StickerResponse) {
        self.init(stickerId: response.stickerId,
                  name: response.name,
                  assetUrl: response.assetUrl,
                  assetType: response.assetType,
                  assetWidth: response.assetWidth,
                  assetHeight: response.assetHeight,
                  lastUseAt: nil)
    }
    
}

extension Sticker: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case stickerId = "sticker_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case lastUseAt = "last_used_at"
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
    }
    
}

extension Sticker: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "stickers"
    
}
