import Foundation

public final class Web3TokenItem: Web3Token, DepositNetworkReportingToken, HideableToken {
    
    public let isHidden: Bool
    public let chain: Chain?
    
    required init(from decoder: Decoder) throws {
        
        enum JoinedCodingKeys: String, CodingKey {
            case hidden
        }
        
        let container = try decoder.container(keyedBy: JoinedCodingKeys.self)
        self.isHidden = try container.decode(Bool.self, forKey: .hidden)
        self.chain = try? Chain(joinedDecoder: decoder)
        try super.init(from: decoder)
    }
    
}
