import Foundation
import MixinServices

extension Wallet {
    
    var localizedName: String {
        switch self {
        case .privacy:
            R.string.localizable.privacy_wallet()
        case .common(let wallet):
            wallet.name
        case .safe(let wallet):
            wallet.name
        }
    }
    
}

extension Wallet {
    
    enum Tag {
        case plain(String)
        case warning(String)
        case safeOwner(String)
    }
    
}
