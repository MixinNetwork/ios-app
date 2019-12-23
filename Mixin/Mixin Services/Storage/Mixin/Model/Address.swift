import Foundation
import WCDBSwift

public struct Address: BaseCodable {
    
    static let tableName = "addresses"
    
    let type: String
    let addressId: String
    let assetId: String
    let destination: String
    let label: String
    let tag: String
    let fee: String
    let reserve: String
    let dust: String
    let updatedAt: String
    
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

    var fullAddress: String {
        return tag.isEmpty ? destination : "\(destination):\(tag)"
    }

}
