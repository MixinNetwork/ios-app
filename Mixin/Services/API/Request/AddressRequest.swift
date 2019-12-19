import Foundation
import UIKit

struct AddressRequest: Codable {

    let assetId: String
    let destination: String
    let tag: String
    let label: String
    var pin: String


    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case pin
    }
}

extension AddressRequest {

    var fullAddress: String {
        return tag.isEmpty ? destination : "\(destination):\(tag)"
    }

}


