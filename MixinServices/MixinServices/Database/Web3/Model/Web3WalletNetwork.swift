import Foundation

public final class Web3WalletNetwork: Decodable, MixinFetchableRecord {
    
    enum CodingKeys: String, CodingKey {
        case name
        case chainID = "chain_id"
        case iconURL = "icon_url"
        case path
        case destination
    }
    
    public let name: String
    public let chainID: String
    public let iconURL: String
    public let path: String
    public let compactAddress: String
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let destination = try container.decode(String.self, forKey: .destination)
        name = try container.decode(String.self, forKey: .name)
        chainID = try container.decode(String.self, forKey: .chainID)
        iconURL = try container.decode(String.self, forKey: .iconURL)
        path = try container.decode(String.self, forKey: .path)
        compactAddress = Address.compactRepresentation(of: destination)
    }
    
}
