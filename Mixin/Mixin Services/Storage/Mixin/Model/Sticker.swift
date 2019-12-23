import Foundation
import WCDBSwift

public struct Sticker: BaseCodable {
    
    static var tableName: String = "stickers"
    
    let stickerId: String
    let name: String
    let assetUrl: String
    let assetType: String
    let assetWidth: Int
    let assetHeight: Int
    var lastUseAt: String?
    
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
}

extension Sticker {
    
    static func createSticker(from sticker: StickerResponse) -> Sticker {
        return Sticker(stickerId: sticker.stickerId, name: sticker.name, assetUrl: sticker.assetUrl, assetType: sticker.assetType, assetWidth: sticker.assetWidth, assetHeight: sticker.assetHeight, lastUseAt: nil)
    }
    
}
