import Foundation
import MixinServices

extension Wallet {
    
    var localizedName: String {
        switch self {
        case .privacy:
            R.string.localizable.privacy_wallet()
        case .common(let wallet):
            wallet.localizedName
        }
    }
    
}

extension Web3Wallet {
    
    var localizedName: String {
        switch category.knownCase {
        case .classic:
            R.string.localizable.common_wallet()
        case .importedMnemonic, .importedPrivateKey, .watchAddress, .none:
            name
        }
    }
    
}
