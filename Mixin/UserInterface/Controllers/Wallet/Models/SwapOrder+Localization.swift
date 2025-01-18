import Foundation
import MixinServices

extension SwapOrder.State: AnyLocalized {
    
    var localizedDescription: String {
        switch self {
        case .pending:
            R.string.localizable.pending()
        case .success:
            R.string.localizable.completed()
        case .failed:
            R.string.localizable.failed()
        case .refunded:
            R.string.localizable.refunded()
        }
    }
    
}

extension SwapOrder.OrderType: AnyLocalized {
    
    var localizedDescription: String {
        switch self {
        case .swap:
            R.string.localizable.order_type_swap()
        case .limit:
            R.string.localizable.order_type_limit()
        }
    }
    
}
