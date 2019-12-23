import Foundation
import WCDBSwift

public struct StickerRelationship: BaseCodable {
    
    public static let tableName: String = "sticker_relationships"
    
    public let albumId: String
    public let stickerId: String
    public let createdAt: String
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = StickerRelationship
        case albumId = "album_id"
        case stickerId = "sticker_id"
        case createdAt = "created_at"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: albumId, stickerId)
            ]
        }
    }
    
}
