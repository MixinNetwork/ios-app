import Foundation
import WCDBSwift

struct ResendSessionMessage: BaseCodable {
    
    public static let tableName: String = "resend_session_messages"
    
    public let messageId: String
    public let userId: String
    public let sessionId: String
    public let status: Int
    
    enum CodingKeys: String, CodingTableKey {
        
        typealias Root = ResendSessionMessage
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: messageId, userId, sessionId)
            ]
        }
        
        case messageId = "message_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case status
        
    }
    
}
