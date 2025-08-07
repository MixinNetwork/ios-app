import Foundation

public final class WalletDigest {
    
    public let wallet: Wallet
    
    // A Legacy Address refers to an address with a nil path. If a classic wallet contains a Legacy Address, it means the wallet was created with an older version, and no explicit name was assigned during its creation. For other categories of wallet, it means nothing.
    public let hasLegacyAddresses: Bool
    
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    public let supportedChainIDs: Set<String>
    
    public init(
        wallet: Wallet,
        hasLegacyAddresses: Bool,
        tokens: [TokenDigest],
        supportedChainIDs: Set<String>
    ) {
        self.wallet = wallet
        self.hasLegacyAddresses = hasLegacyAddresses
        self.usdBalanceSum = tokens.reduce(0) { result, digest in
            result + digest.decimalValue
        }
        self.tokens = tokens
        self.supportedChainIDs = supportedChainIDs
    }
    
}
