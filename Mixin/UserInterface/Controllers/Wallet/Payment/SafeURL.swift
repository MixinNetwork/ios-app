import Foundation
import MixinServices

enum SafeURL {
    
    case payment(SafePaymentURL)
    case multisig(MultisigURL)
    case code(String)
    case tip(TIPURL)
    case inscription(String)
    case swap(input: String?, output: String?, referral: String?)
    case send(ExternalSharingContext)
    case market(id: String)
    case membership
    case referral(String)
    
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
            switch pathComponents.count {
            case 2 where pathComponents[1] == "swap":
                var input, output, referral: String?
                if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems {
                    for item in queryItems {
                        switch item.name {
                        case "input":
                            input = item.value
                        case "output":
                            output = item.value
                        case "referral":
                            referral = item.value
                        default:
                            break
                        }
                    }
                }
                self = .swap(input: input, output: output, referral: referral)
            case 2 where pathComponents[1] == "send":
                if let context = ExternalSharingContext(url: url) {
                    self = .send(context)
                } else {
                    return nil
                }
            case 2 where pathComponents[1] == "membership":
                self = .membership
            case 3 where pathComponents[1] == "schemes":
                let uuid = pathComponents[2]
                if UUID.isValidLowercasedUUIDString(uuid) {
                    self = .code(uuid)
                } else {
                    return nil
                }
            case 3 where pathComponents[1] == "inscriptions":
                let hash = pathComponents[2]
                if Inscription.isHashValid(hash) {
                    self = .inscription(hash)
                } else {
                    return nil
                }
            case 3 where pathComponents[1] == "markets":
                let id = pathComponents[2]
                self = .market(id: id)
            case 3 where pathComponents[1] == "referrals":
                let code = pathComponents[2]
                self = .referral(code)
            default:
                return nil
            }
        }
    }
    
}
