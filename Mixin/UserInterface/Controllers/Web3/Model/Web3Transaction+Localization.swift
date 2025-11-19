import Foundation
import MixinServices

extension UnknownableEnum<Web3Transaction.TransactionType> {
    
    var localized: String {
        switch self {
        case .known(let type):
            switch type {
            case .transferIn:
                R.string.localizable.receive()
            case .transferOut:
                R.string.localizable.send()
            case .swap:
                R.string.localizable.trade()
            case .approval:
                R.string.localizable.approval()
            case .unknown:
                "Unknown"
            }
        case .unknown(let rawValue):
            rawValue
        }
    }
    
}
