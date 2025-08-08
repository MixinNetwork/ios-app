import Foundation
import MixinServices

extension Wallet {
    
    var localizedName: String {
        switch self {
        case .privacy:
            R.string.localizable.privacy_wallet()
        case .common(let wallet):
            wallet.name
        }
    }
    
}
