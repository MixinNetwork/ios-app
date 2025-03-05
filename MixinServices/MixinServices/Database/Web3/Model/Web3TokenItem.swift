import Foundation

public final class Web3TokenItem: Web3Token, DepositNetworkReportingToken {
    
    public let chain: Chain?
    
    required init(from decoder: Decoder) throws {
        self.chain = try? Chain(joinedDecoder: decoder)
        try super.init(from: decoder)
    }
    
    public init(token t: Web3Token, chain: Chain?) {
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
