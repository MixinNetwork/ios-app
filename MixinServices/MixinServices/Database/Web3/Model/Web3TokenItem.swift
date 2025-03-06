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
    
    public func replacingChain(with chain: Chain?) -> Web3TokenItem {
        Web3TokenItem(token: self, hidden: self.isHidden, chain: chain)
    }
    
    private init(token t: Web3Token, hidden: Bool, chain: Chain?) {
        self.isHidden = hidden
        self.chain = chain
        super.init(
            walletID:       t.walletID,
            assetID:        t.assetID,
            chainID:        t.chainID,
            assetKey:       t.assetKey,
            kernelAssetID:  t.kernelAssetID,
            symbol:         t.symbol,
            name:           t.name,
            precision:      t.precision,
            iconURL:        t.iconURL,
            amount:         t.amount,
            usdPrice:       t.usdPrice,
            usdChange:      t.usdChange
        )
    }
    
}
