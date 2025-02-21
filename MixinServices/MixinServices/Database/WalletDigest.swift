import Foundation

public final class WalletDigest {
    
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    public let positiveUSDBalanceTokensCount: Int
    
    init(usdBalanceSum: Decimal, tokens: [TokenDigest], positiveUSDBalanceTokensCount: Int) {
        self.usdBalanceSum = usdBalanceSum
        self.tokens = tokens
        self.positiveUSDBalanceTokensCount = positiveUSDBalanceTokensCount
    }
    
}
