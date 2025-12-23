import Foundation
import MixinServices

extension SafeRole: AnyLocalized {
    
    var localizedDescription: String {
        switch self {
        case .owner:
            R.string.localizable.safe_vault_owner()
        case .member:
            R.string.localizable.safe_vault_member()
        }
    }
    
}
