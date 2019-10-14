import Foundation
import WCDBSwift

struct Address: BaseCodable {
    
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
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = Address
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
        
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                addressId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}

extension Address {

    var fullAddress: String {
        return tag.isEmpty ? destination : "\(destination):\(tag)"
    }

}
