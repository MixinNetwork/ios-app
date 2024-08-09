import UIKit

public final class AddressItem: Address {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenIconURL = "token_icon_url"
        case tokenChainIconURL = "token_chain_icon_url"
    }
    
    public let tokenIconURL: String?
    public let tokenChainIconURL: String?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        self.tokenIconURL = try container.decodeIfPresent(String.self, forKey: .tokenIconURL)
        self.tokenChainIconURL = try container.decodeIfPresent(String.self, forKey: .tokenChainIconURL)
        try super.init(from: decoder)
    }
    
}
