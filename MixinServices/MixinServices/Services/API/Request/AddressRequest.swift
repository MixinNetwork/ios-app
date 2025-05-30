import Foundation

public struct AddressRequest {
    
    public let chainID: String
    public let assetID: String
    public let destination: String
    public let tag: String
    public let label: String
    public var pin: String
    
    public init(chainID: String, assetID: String, destination: String, tag: String, label: String, pin: String) {
        self.chainID = chainID
        self.assetID = assetID
        self.destination = destination
        self.tag = tag
        self.label = label
        self.pin = pin
    }
    
}

extension AddressRequest: Codable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case assetID = "asset_id"
        case destination
        case label
        case tag
        case pin = "pin_base64"
    }
    
}
