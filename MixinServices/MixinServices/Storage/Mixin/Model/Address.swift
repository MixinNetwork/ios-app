import Foundation
import WCDBSwift

public struct Address: BaseCodable {
    
    public static let tableName = "addresses"
    
    public let type: String
    public let addressId: String
    public let assetId: String
    public let destination: String
    public let label: String
    public let tag: String
    public let fee: String
    public let reserve: String
    public let dust: String
    public let updatedAt: String
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = Address
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                addressId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case fee
        case reserve
        case dust
        case updatedAt = "updated_at"
        
    }
    
}

extension Address {
    
    public var fullAddress: String {
        return tag.isEmpty ? destination : "\(destination):\(tag)"
    }
    
}
