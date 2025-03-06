import Foundation

public final class WalletDigest {
    
    public let wallet: Wallet
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    public let positiveUSDBalanceTokensCount: Int
    
    init(
        wallet: Wallet,
        usdBalanceSum: Decimal,
        tokens: [TokenDigest],
        positiveUSDBalanceTokensCount: Int
    ) {
        self.wallet = wallet
        self.usdBalanceSum = usdBalanceSum
        self.tokens = tokens
        self.positiveUSDBalanceTokensCount = positiveUSDBalanceTokensCount
    }
    
}
