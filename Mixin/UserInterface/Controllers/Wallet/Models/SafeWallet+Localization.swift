import Foundation
import MixinServices

extension SafeWallet {
    
    var localizedRole: String? {
        switch role {
        case .known(.owner):
            R.string.localizable.safe_vault_owner()
        case .known(.member):
            R.string.localizable.safe_vault_member()
        case .unknown(let role):
            role
        }
    }
    
}
