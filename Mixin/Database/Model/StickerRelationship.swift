import Foundation
import WCDBSwift

struct StickerRelationship: BaseCodable {

    static var tableName: String = "sticker_relationships"

    let albumId: String
    let stickerId: String
    let createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerRelationship
        case albumId = "album_id"
        case stickerId = "sticker_id"
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: albumId, stickerId)
            ]
        }
    }
}
