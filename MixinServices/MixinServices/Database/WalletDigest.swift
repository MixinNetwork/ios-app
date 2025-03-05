import Foundation

public final class WalletDigest {
    
    public enum WalletType {
        case privacy
        case classic(id: String)
    }
    
    public let type: WalletType
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    public let positiveUSDBalanceTokensCount: Int
    
    init(
        type: WalletType,
        usdBalanceSum: Decimal,
        tokens: [TokenDigest],
        positiveUSDBalanceTokensCount: Int
    ) {
        self.type = type
        self.usdBalanceSum = usdBalanceSum
        self.tokens = tokens
        self.positiveUSDBalanceTokensCount = positiveUSDBalanceTokensCount
    }
    
}
