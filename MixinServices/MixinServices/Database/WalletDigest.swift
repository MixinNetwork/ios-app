import Foundation

public final class WalletDigest {
    
    public let wallet: Wallet
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    
    public init(wallet: Wallet, tokens: [TokenDigest]) {
        self.wallet = wallet
        self.usdBalanceSum = tokens.reduce(0) { result, digest in
            result + digest.decimalValue
        }
        self.tokens = tokens
    }
    
}
