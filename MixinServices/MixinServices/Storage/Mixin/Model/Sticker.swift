import Foundation
import WCDBSwift

public struct Sticker: BaseCodable {
    
    public static let tableName: String = "stickers"
    
    public let stickerId: String
    public let name: String
    public let assetUrl: String
    public let assetType: String
    public let assetWidth: Int
    public let assetHeight: Int
    public var lastUseAt: String?
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = Sticker
        case stickerId = "sticker_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case lastUseAt = "last_used_at"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                stickerId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
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
