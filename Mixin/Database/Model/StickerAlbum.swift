import Foundation
import WCDBSwift

struct StickerAlbum: BaseCodable {

    static var tableName: String = "sticker_albums"

    let category: String?
    let albumId: String
    let name: String
    let iconUrl: String
    let createdAt: String
    let updateAt: String
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = StickerAlbum
        case albumId = "album_id"
        case name
        case category
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

extension StickerAlbum {

    func getStickerCategory() -> String {
        switch category ?? "" {
        case AlbumCategory.FAVORITE.rawValue:
            return AlbumCategory.FAVORITE.rawValue
        default:
            return AlbumCategory.SYSTEM.rawValue
        }
    }

}

enum AlbumCategory: String {
    case FAVORITE
    case SYSTEM
}
