import Foundation
import WCDBSwift

struct Sticker: BaseCodable {

    static var tableName: String = "stickers"

    let albumId: String
    let name: String
    let assetUrl: String
    let assetType: String
    let assetWidth: Int
    let assetHeight: Int
    let lastUseAt: String?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Sticker
        case albumId = "album_id"
        case name
        case assetUrl = "asset_url"
        case assetType = "asset_type"
        case assetWidth = "asset_width"
        case assetHeight = "asset_height"
        case lastUseAt = "last_used_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: albumId, name)
            ]
        }
    }
}
