import Foundation
import MixinServices

enum AccountVerificationMethod: Int {
    
    case signUp
    case signUpWithBIP39Mnemonics
    case signInWithMixinMnemonics
    case signInWithBIP39Mnemonics
    case signInWithMobileNumber
    
    var isSigningUp: Bool {
        switch self {
        case .signUp, .signUpWithBIP39Mnemonics:
            true
        case .signInWithMixinMnemonics, .signInWithBIP39Mnemonics, .signInWithMobileNumber:
            false
        }
    }
    
}

extension AccountVerificationMethod: CustomDebugStringConvertible {
    
    var debugDescription: String {
        switch self {
        case .signUp:
            "SignUp"
        case .signUpWithBIP39Mnemonics:
            "SignUp-BIP39Mnemonics"
        case .signInWithMixinMnemonics:
            "SignIn-MixinMnemonics"
        case .signInWithBIP39Mnemonics:
            "SignIn-BIP39Mnemonics"
        case .signInWithMobileNumber:
            "SignIn-MobileNumber"
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
