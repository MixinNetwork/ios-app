import Foundation
import WCDBSwift

public struct StickerRelationship: BaseCodable {
    
    static var tableName: String = "sticker_relationships"
    
    let albumId: String
    let stickerId: String
    let createdAt: String
    
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
