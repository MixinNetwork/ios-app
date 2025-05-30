import Foundation
import MixinServices

extension TransferLinkError: @retroactive LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .notTransferLink, .invalidFormat:
            R.string.localizable.invalid_payment_link()
        case .assetNotFound:
            R.string.localizable.asset_not_found()
        case .alreadyPaid:
            R.string.localizable.pay_paid()
        case let .requestError(err):
            err.localizedDescription
        }
    }
}

