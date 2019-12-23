import Foundation
import WCDBSwift

struct MessageHistory: BaseCodable {
    
    public static let tableName: String = "messages_history"
    
    public let messageId: String
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = MessageHistory
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
        case messageId = "message_id"
    }
    
}
