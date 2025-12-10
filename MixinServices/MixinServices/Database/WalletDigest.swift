import Foundation

public final class WalletDigest {
    
    // If a classic wallet contains an address with a nil path,
    // it means the wallet was created with an older version,
    // and no explicit name was assigned during its creation.
    // Therefore, it needs to be renamed.
    public enum LegacyClassicWalletRenaming {
        
        case notInvolved
        case required
        case done
        
        // A Legacy Address refers to an address with a nil path
        public init(wallet: Wallet, hasLegacyAddress: Bool) {
            switch wallet {
            case .privacy:
                self = .notInvolved
            case .common(let wallet):
                switch wallet.category.knownCase {
                case .classic:
                    self = hasLegacyAddress ? .required : .done
                case .importedMnemonic, .importedPrivateKey, .watchAddress, .mixinSafe, .none:
                    self = .notInvolved
                }
            }
        }
        
    }
    
    public let wallet: Wallet
    public let usdBalanceSum: Decimal
    public let tokens: [TokenDigest]
    public let supportedChainIDs: Set<String>
    public let legacyClassicWalletRenaming: LegacyClassicWalletRenaming
    
    public init(
        wallet: Wallet,
        tokens: [TokenDigest],
        supportedChainIDs: Set<String>,
        hasLegacyAddress: Bool,
    ) {
        self.wallet = wallet
        self.usdBalanceSum = tokens.reduce(0) { result, digest in
            result + digest.decimalValue
        }
        self.tokens = tokens
        self.supportedChainIDs = supportedChainIDs
        self.legacyClassicWalletRenaming = LegacyClassicWalletRenaming(
            wallet: wallet,
            hasLegacyAddress: hasLegacyAddress
        )
    }
    
}
