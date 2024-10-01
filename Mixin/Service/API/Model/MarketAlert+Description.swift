import Foundation
import MixinServices

extension MarketAlert {
    
    enum Action: String {
        case pause
        case resume
        case delete
    }
    
}

extension MarketAlert.AlertType {
    
    var description: String {
        switch self {
        case .priceReached:
            R.string.localizable.alert_type_price_reached()
        case .priceIncreased:
            R.string.localizable.alert_type_price_increased()
        case .priceDecreased:
            R.string.localizable.alert_type_price_decreased()
        case .percentageIncreased:
            R.string.localizable.alert_type_percentage_increased()
        case .percentageDecreased:
            R.string.localizable.alert_type_percentage_decreased()
        }
    }
    
}

extension MarketAlert.AlertFrequency {
    
    var description: String {
        switch self {
        case .every:
            R.string.localizable.alert_frequency_every()
        case .daily:
            R.string.localizable.alert_frequency_daily()
        case .once:
            R.string.localizable.alert_frequency_once()
        }
    }
    
}
