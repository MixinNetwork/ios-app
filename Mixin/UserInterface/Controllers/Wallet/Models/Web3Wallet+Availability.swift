import Foundation
import MixinServices

extension Web3Wallet {
    
    enum Availability {
        
        case always
        case never
        case afterImportingMnemonics
        case afterImportingPrivateKey(Web3Chain.Kind)
        
        init(
            wallet: Web3Wallet,
            importedSecret: CommonWalletImportedSecret?,
            supportedChainIDs: Set<String>,
        ) {
            self = switch wallet.category.knownCase {
            case .classic:
                    .always
            case .importedMnemonic:
                if importedSecret == nil {
                    .afterImportingMnemonics
                } else {
                    .always
                }
            case .importedPrivateKey:
                if importedSecret == nil {
                    if let kind = Web3Chain.Kind.singleKindWallet(chainIDs: supportedChainIDs) {
                        .afterImportingPrivateKey(kind)
                    } else {
                        .never
                    }
                } else {
                    .always
                }
            case .watchAddress, .none:
                    .never
            }
        }
        
    }
    
    func hasSecret() -> Bool {
        switch category.knownCase {
        case .classic:
            true
        case .importedMnemonic:
            AppGroupKeychain.importedMnemonics(walletID: walletID) != nil
        case .importedPrivateKey:
            AppGroupKeychain.importedPrivateKey(walletID: walletID) != nil
        case .watchAddress, .none:
            false
        }
    }
    
}
