import Foundation

enum SafeURL {
    
    case payment(SafePaymentURL)
    case multisig(MultisigURL)
    case code(CodeURL)
    case tip(TIPURL)
    
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
        } else if let code = CodeURL(url: url) {
            self = .code(code)
        } else if let tip = TIPURL(url: url) {
            self = .tip(tip)
        } else {
            return nil
        }
    }
    
}
