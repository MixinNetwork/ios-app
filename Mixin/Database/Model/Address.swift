import Foundation
import WCDBSwift

struct Address: BaseCodable {
    
    static let tableName = "addresses"
    
    let type: String
    let addressId: String
    let assetId: String
    let updatedAt: String
    let fee: String
    let reserve: String
    let destination: String
    let label: String
    let tag: String
    let dust: String
    
    enum CodingKeys: String, CodingTableKey {
        typealias Root = Address
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case destination
        case label
        case updatedAt = "updated_at"
        case fee
        case reserve
        case tag
        case dust
        
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
