import Foundation
import MixinServices

extension UTXOService.CollectingError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .insufficientBalance:
            return R.string.localizable.insufficient_balance()
        case .maxSpendingCountExceeded:
            return R.string.localizable.utxo_count_exceeded()
        }
    }
    
}
