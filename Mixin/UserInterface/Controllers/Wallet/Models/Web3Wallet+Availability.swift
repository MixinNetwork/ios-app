import Foundation
import MixinServices

extension Web3Wallet {
    
    enum Availability {
        
        case always
        case never
        case afterImportingMnemonics
        case afterImportingPrivateKey
        
        init(wallet: Web3Wallet, secret: CommonWalletSecret?) {
            self = switch wallet.category.knownCase {
            case .classic:
                    .always
            case .importedMnemonic:
                if secret == nil {
                    .afterImportingMnemonics
                } else {
                    .always
                }
            case .importedPrivateKey:
                if secret == nil {
                    .afterImportingPrivateKey
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
