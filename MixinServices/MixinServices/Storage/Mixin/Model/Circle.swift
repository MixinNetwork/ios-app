import UIKit
import WCDBSwift

public class Circle: BaseCodable {
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = Circle
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                circleId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
        case circleId = "circle_id"
        case name
        case createdAt = "created_at"
        
    }
    
    public static let tableName: String = "circles"
    
    public let circleId: String
    public let name: String
    public let createdAt: String
    
    public init(circleId: String, name: String, createdAt: String) {
        self.circleId = circleId
        self.name = name
        self.createdAt = createdAt
    }
    
}
