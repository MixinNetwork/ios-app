import Foundation
import WCDBSwift

struct StickerAlbum: BaseCodable {

    static var tableName: String = "sticker_albums"

    let albumId: String
    let stickerId: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerAlbum
        case albumId = "album_id"
        case stickerId = "sticker_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: albumId, stickerId)
            ]
        }
    }
}
