import Foundation

enum WalletConnectRejectionReason {
    
    case userRejected
    case mismatchedAddress
    case exception(Error)
    
}

extension WalletConnectRejectionReason: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .userRejected:
            return "User rejected"
        case .mismatchedAddress:
            return "Mismatched address"
        case .exception(let error):
            return "Internal error: \(error)"
        }
    }
    
}
