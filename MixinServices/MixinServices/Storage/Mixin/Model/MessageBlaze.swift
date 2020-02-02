import Foundation
import WCDBSwift

struct MessageBlaze: BaseCodable {
    
    public static let tableName: String = "messages_blaze"
    
    public let messageId: String
    public let message: Data
    public let createdAt: String
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = MessageBlaze
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index": IndexBinding(indexesBy: [createdAt])
            ]
        }
        
        case messageId = "_id"
        case message
        case createdAt = "created_at"
        
    }
    
}
