import Foundation
import WCDBSwift

struct StickerAlbum: BaseCodable {

    static var tableName: String = "sticker_albums"

    let albumId: String
    let name: String
    let iconUrl: String
    let createdAt: String
    let updateAt: String
    let userId: String
    let category: String
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerAlbum
        case albumId = "album_id"
        case name
        case iconUrl = "icon_url"
        case createdAt = "created_at"
        case updateAt = "update_at"
        case userId = "user_id"
        case category

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                albumId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}
enum AlbumCategory: String {
    case PERSONAL
    case SYSTEM
}
