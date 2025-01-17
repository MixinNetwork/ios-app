import Foundation
import MixinServices

extension SwapOrder.State {
    
    var localizedString: String {
        switch self {
        case .pending:
            R.string.localizable.pending()
        case .success:
            "Completed"
        case .failed:
            "Failed"
        case .refunded:
            "Refunded"
        }
    }
    
}

extension SwapOrder.OrderType {
    
    var localizedString: String {
        switch self {
        case .swap:
            "Swap"
        case .limit:
            "Limit"
        }
    }
    
}
