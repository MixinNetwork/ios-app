import Foundation
import WCDBSwift

struct StickerAlbum: BaseCodable {

    static var tableName: String = "sticker_albums"

    let albumId: String
    let name: String
    let iconUrl: String
    let createdAt: String
    let updateAt: String
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerAlbum
        case albumId = "album_id"
        case name
        case iconUrl = "icon_url"
        case createdAt = "created_at"
        case updateAt = "update_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                albumId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}
