import Foundation
import MixinServices

enum AccountVerificationMethod: Int {
    case signUp
    case signInWithMixinMnemonics
    case signInWithBIP39Mnemonics
    case signInWithMobileNumber
}

extension AccountVerificationMethod: CustomDebugStringConvertible {
    
    var debugDescription: String {
        switch self {
        case .signUp:
            "SignUp"
        case .signInWithMixinMnemonics:
            "SignInWithMixinMnemonics"
        case .signInWithBIP39Mnemonics:
            "SignInWithBIP39Mnemonics"
        case .signInWithMobileNumber:
            "SignInWithMobileNumber"
        }
    }
    
}

extension AccountVerificationMethod {
    
    static var current: AccountVerificationMethod? {
        get {
            if let rawValue = AppGroupUserDefaults.accountVerificationMethod {
                AccountVerificationMethod(rawValue: rawValue)
            } else {
                nil
            }
        }
        set {
            AppGroupUserDefaults.accountVerificationMethod = newValue?.rawValue
        }
    }
    
}
