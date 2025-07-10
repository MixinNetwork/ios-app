import Foundation
import MixinServices

extension Web3Wallet {
    
    var localizedName: String {
        switch category.knownCase {
        case .classic:
            R.string.localizable.common_wallet()
        case .importedMnemonic, .importedPrivateKey, .none:
            name
        }
    }
    
}
