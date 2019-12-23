import WCDBSwift

public class SenderKey: BaseCodable {
    
    public static var tableName: String = "sender_keys"
    
    public let groupId: String
    public let senderId: String
    public let record: Data
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = SenderKey
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            return  [
                "_multi_primary": MultiPrimaryBinding(indexesBy: groupId, senderId)
            ]
        }
        
        case groupId
        case senderId
        case record
        
    }
    
    public init(groupId: String, senderId: String, record: Data) {
        self.groupId = groupId
        self.senderId = senderId
        self.record = record
    }
    
}
