import Foundation
import UIKit

struct AddressRequest: Codable {

    let assetId: String
    let publicKey: String
    let tag: String
    let label: String
    var pin: String


    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case publicKey = "public_key"
        case label
        case tag
        case pin
    }
}

extension AddressRequest {

    var fullAddress: String {
        return tag.isEmpty ? publicKey : "\(publicKey):\(tag)"
    }

}


