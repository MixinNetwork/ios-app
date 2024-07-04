import Foundation
import MixinServices

enum SafeURL {
    
    case payment(SafePaymentURL)
    case multisig(MultisigURL)
    case code(String)
    case tip(TIPURL)
    case inscription(String)
    
}

extension SafeURL {
    
    private static let schemes = ["mixin", "https"]
    private static let host = "mixin.one"
    
    init?(url: URL) {
        guard let scheme = url.scheme, Self.schemes.contains(scheme) else {
            return nil
        }
        guard url.host == Self.host else {
            return nil
        }
        if let payment = SafePaymentURL(url: url) {
            self = .payment(payment)
        } else if let multisig = MultisigURL(url: url) {
            self = .multisig(multisig)
        } else if let tip = TIPURL(url: url) {
            self = .tip(tip)
        } else {
            let pathComponents = url.pathComponents
            if pathComponents.count == 3, pathComponents[1] == "schemes" {
                let uuid = pathComponents[2]
                if UUID.isValidLowercasedUUIDString(uuid) {
                    self = .code(uuid)
                } else {
                    return nil
                }
            } else if pathComponents.count == 3, pathComponents[1] == "inscriptions" {
                let hash = pathComponents[2]
                if Inscription.isHashValid(hash) {
                    self = .inscription(hash)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
}
