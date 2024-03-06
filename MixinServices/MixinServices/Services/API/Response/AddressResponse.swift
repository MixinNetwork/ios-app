import Foundation

public struct AddressResponse: Codable {
    
    public let destination: String
    public let tag: String?
    
    enum CodingKeys: String, CodingKey {
        case destination
        case tag
    }
    
}
