import Foundation
import MixinServices

extension MembershipOrder.Status {
    
    var localizedDescription: String {
        switch self {
        case .initial:
            R.string.localizable.pending()
        case .paid:
            R.string.localizable.completed()
        case .cancel:
            R.string.localizable.canceled()
        case .expired:
            R.string.localizable.expired()
        case .failed:
            R.string.localizable.failed()
        }
    }
    
}

extension UnknownableEnum<MembershipOrder.Status> {
    
    var localizedDescription: String {
        switch self {
        case .known(let status):
            status.localizedDescription
        case .unknown(let rawValue):
            rawValue
        }
    }
    
}
