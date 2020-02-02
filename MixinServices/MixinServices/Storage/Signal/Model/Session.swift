import WCDBSwift

public struct Session: BaseCodable {
    
    public static var tableName: String = "sessions"
    
    public var id: Int?
    public let address: String
    public let device: Int
    public let record: Data
    public let timestamp: TimeInterval
    
    public init(address: String, device: Int, record: Data, timestamp: TimeInterval) {
        self.address = address
        self.device = device
        self.record = record
        self.timestamp = timestamp
    }
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = Session
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                id: ColumnConstraintBinding(isPrimary: true, isAutoIncrement: true)
            ]
        }
        public static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return  [
                "_multi_index": IndexBinding(isUnique: true, indexesBy: address, device)
            ]
        }
        
        case id
        case address
        case device
        case record
        case timestamp
        
    }
    
    public var isAutoIncrement: Bool {
        return true
    }
    
}
