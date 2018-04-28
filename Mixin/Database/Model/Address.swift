import Foundation
import WCDBSwift

struct Address: BaseCodable {
    
    static let tableName = "addresses"
    
    let type: String
    let addressId: String
    let assetId: String
    let publicKey: String
    let label: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = Address
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case publicKey = "public_key"
        case label
        case updatedAt = "updated_at"
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                addressId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}
