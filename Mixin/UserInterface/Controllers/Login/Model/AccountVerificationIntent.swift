import Foundation
import MixinServices

enum AccountVerificationIntent {
    
    enum Method: Int, CustomDebugStringConvertible {
        
        case mobileNumber   = 1
        case bip39Mnemonics = 2
        case mixinMnemonics = 3
        
        var debugDescription: String {
            switch self {
            case .mobileNumber:
                "MobileNumber"
            case .bip39Mnemonics:
                "BIP39Mnemonics"
            case .mixinMnemonics:
                "MixinMnemonics"
            }
        }
        
    }
    
    case signUp(Method)
    case signIn(Method)
    
}

extension AccountVerificationIntent: RawRepresentable {
    
    var rawValue: Int {
        switch self {
        case .signUp(let method):
            method.rawValue
        case .signIn(let method):
            -method.rawValue
        }
    }
    
    init?(rawValue: Int) {
        if rawValue > 0, let method = Method(rawValue: rawValue) {
            self = .signUp(method)
        } else if rawValue < 0, let method = Method(rawValue: -rawValue) {
            self = .signIn(method)
        } else {
            return nil
        }
    }
    
}

extension AccountVerificationIntent: CustomDebugStringConvertible {
    
    var debugDescription: String {
        switch self {
        case .signUp(let method):
            "SignUp-" + method.debugDescription
        case .signIn(let method):
            "SignIn-" + method.debugDescription
        }
    }
    
}

extension AccountVerificationIntent {
    
    static var current: AccountVerificationIntent? {
        get {
            if let rawValue = AppGroupUserDefaults.accountVerificationIntent {
                AccountVerificationIntent(rawValue: rawValue)
            } else {
                nil
            }
        }
        set {
            AppGroupUserDefaults.accountVerificationIntent = newValue?.rawValue
        }
    }
    
}
