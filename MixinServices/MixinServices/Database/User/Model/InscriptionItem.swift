import Foundation
import GRDB

public final class InscriptionItem: Inscription {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case collectionName = "collection_name"
        case collectionIconURL = "collection_icon_url"
        
        case tokenName = "token_name"
        case tokenSymbol = "token_symbol"
        case tokenIconUrl = "token_icon_url"
    }
    
    public var collectionName: String?
    public var collectionIconURL: String?
    
    public let tokenName: String
    public let tokenSymbol: String
    public let tokenIconUrl: String
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        
        self.collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        self.collectionIconURL = try container.decodeIfPresent(String.self, forKey: .collectionIconURL)
        
        self.tokenName = try container.decode(String.self, forKey: .tokenName)
        self.tokenSymbol = try container.decode(String.self, forKey: .tokenSymbol)
        self.tokenIconUrl = try container.decode(String.self, forKey: .tokenIconUrl)
        
        try super.init(from: decoder)
    }
}
