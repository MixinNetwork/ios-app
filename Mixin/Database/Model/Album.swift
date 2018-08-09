import Foundation
import WCDBSwift

struct Album: BaseCodable {

    static var tableName: String = "albums"

    let albumId: String
    let name: String
    let iconUrl: String
    let createdAt: String
    let updatedAt: String
    let userId: String
    let category: String
    let description: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Album
        case albumId = "album_id"
        case name
        case iconUrl = "icon_url"
        case createdAt = "created_at"
        case updatedAt = "update_at"
        case userId = "user_id"
        case category
        case description

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
