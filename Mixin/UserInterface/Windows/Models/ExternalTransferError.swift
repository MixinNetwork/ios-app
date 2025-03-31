import Foundation

enum ExternalTransferError: Error, LocalizedError {
    
    case invalidPaymentLink
    case syncTokenFailed
    case insufficientBalance
    case insufficientFee
    case alreadyPaid
    
    var errorDescription: String? {
        switch self {
        case .invalidPaymentLink:
            R.string.localizable.invalid_payment_link()
        case .syncTokenFailed:
            R.string.localizable.error_connection_timeout()
        case .insufficientBalance:
            R.string.localizable.insufficient_balance()
        case .insufficientFee:
            R.string.localizable.insufficient_transaction_fee()
        case .alreadyPaid:
            R.string.localizable.pay_paid()
        }
    }
    
}
