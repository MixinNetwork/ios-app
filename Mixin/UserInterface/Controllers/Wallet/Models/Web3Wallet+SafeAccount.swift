import Foundation
import MixinServices

extension Web3Wallet {
    
    var safeRoleTag: String? {
        switch safeRole {
        case .known(.owner):
            R.string.localizable.safe_vault_owner()
        case .known(.member):
            R.string.localizable.safe_vault_member()
        case .unknown(let role):
            role
        case .none:
            nil
        }
    }
    
}
