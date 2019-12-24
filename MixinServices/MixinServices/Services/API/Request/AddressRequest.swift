import Foundation
import UIKit

public struct AddressRequest: Codable {
    
    public let assetId: String
    public let destination: String
    public let tag: String
    public let label: String
    public var pin: String
    
    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case pin
    }
    
    public init(assetId: String, destination: String, tag: String, label: String, pin: String) {
        self.assetId = assetId
        self.destination = destination
        self.tag = tag
        self.label = label
        self.pin = pin
    }
    
}

extension AddressRequest {
    
    public var fullAddress: String {
        return tag.isEmpty ? destination : "\(destination):\(tag)"
    }
    
}
