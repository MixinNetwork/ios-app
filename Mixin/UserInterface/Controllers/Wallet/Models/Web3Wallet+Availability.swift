import Foundation
import MixinServices

extension Web3Wallet {
    
    enum Availability {
        case always
        case never
        case afterImportingMnemonics
        case afterImportingPrivateKey
    }
    
    func hasSecret() -> Bool {
        switch category.knownCase {
        case .classic:
            true
        case .importedMnemonic:
            AppGroupKeychain.importedMnemonics(walletID: walletID) != nil
        case .importedPrivateKey:
            AppGroupKeychain.importedPrivateKey(walletID: walletID) != nil
        case .watchAddress, .mixinSafe, .none:
            false
        }
    }
    
}
