import Foundation

public final class Web3TokenItem: Web3Token, OnChainToken, HideableToken {
    
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
    
    public init(token t: Web3Token, hidden: Bool, chain: Chain?) {
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
            usdChange:      t.usdChange,
            level:          t.level,
        )
    }
    
    public convenience init(
        token: Web3TokenItem,
        replacingAmountWith arbitraryAmount: String
    ) {
        let amountReplacedToken = Web3Token(token: token, replacingAmountWith: arbitraryAmount)
        self.init(token: amountReplacedToken, hidden: false, chain: token.chain)
    }
    
}
